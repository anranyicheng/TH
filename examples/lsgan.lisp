;; from
;; https://wiseodd.github.io/techblog/2017/03/02/least-squares-gan/

(defpackage :lsgan
  (:use #:common-lisp
        #:mu
        #:th
        #:th.image
        #:th.db.mnist))

(in-package :lsgan)

;; load mnist data, takes ~22 secs in macbook 2017
(defparameter *mnist* (read-mnist-data))

;; mnist data has following dataset
;; train-images, train-labels and test-images, test-labels
(prn *mnist*)

(defparameter *output* (format nil "~A/Desktop" (user-homedir-pathname)))

(defun lossd (dr df) ($* 0.5 ($+ ($mean ($expt ($- dr ($one dr)) 2))
                                 ($mean ($expt df 2)))))
(defun lossg (df) ($* 0.5 ($mean ($expt ($- df ($one df)) 2))))

(defun optm (params) ($amgd! params 1E-3))

(defun outpng (data fname &optional (w 28) (h 28))
  (let ((img (opticl:make-8-bit-gray-image w h))
        (d ($reshape data w h)))
    (loop :for i :from 0 :below h
          :do (loop :for j :from 0 :below w
                    :do (progn
                          (setf (aref img i j) (round (* 255 ($ d i j)))))))
    (opticl:write-png-file fname img)))

;; training data - uses batches for performance, it affects quantity as well
(defparameter *batch-size* 30)
(defparameter *batch-count* (/ 60000 *batch-size*))

(defparameter *mnist-train-image-batches*
  (loop :for i :from 0 :below *batch-count*
        :for range = (loop :for k :from (* i *batch-size*) :below (* (1+ i) *batch-size*)
                           :collect k)
        :collect ($contiguous! ($index ($ *mnist* :train-images) 0 range))))

(defparameter *discriminator* (parameters))
(defparameter *generator* (parameters))

(defparameter *gen-size* 10)
(defparameter *hidden-size* 128)
(defparameter *img-size* (* 28 28))

(defun xinit (size) ($* (apply #'rndn size) (/ 1 (sqrt (/ ($ size 0) 2)))))

(defparameter *os* (ones *batch-size*))

;; generator network
(defparameter *gw1* ($push *generator* (xinit (list *gen-size* *hidden-size*))))
(defparameter *gb1* ($push *generator* (zeros *hidden-size*)))
(defparameter *gw2* ($push *generator* (xinit (list *hidden-size* *img-size*))))
(defparameter *gb2* ($push *generator* (zeros *img-size*)))

(defun generate (z)
  (-> z
      ($affine *gw1* *gb1* *os*)
      ($lrelu)
      ($affine *gw2* *gb2* *os*)
      ($clamp -10 10)
      ($sigmoid)))

;; discriminator network
(defparameter *dw1* ($push *discriminator* (xinit (list *img-size* *hidden-size*))))
(defparameter *db1* ($push *discriminator* (zeros *hidden-size*)))
(defparameter *dw2* ($push *discriminator* (xinit (list *hidden-size* 1))))
(defparameter *db2* ($push *discriminator* (zeros 1)))

(defun discriminate (x)
  (-> x
      ($affine *dw1* *db1* *os*)
      ($lrelu)
      ($affine *dw2* *db2* *os*)))

(defun samplez () (rndn *batch-size* *gen-size*))

(defparameter *epoch* 50)
(defparameter *k* 3)

($cg! *discriminator*)
($cg! *generator*)

(defparameter *train-data-batches* (subseq *mnist-train-image-batches* 0))
(defparameter *train-count* ($count *train-data-batches*))

(gcf)

(time
 (loop :for epoch :from 1 :to *epoch*
       :for dloss = 0
       :for gloss = 0
       :do (progn
             ($cg! *discriminator*)
             ($cg! *generator*)
             (prn "*****")
             (prn "EPOCH:" epoch)
             (loop :for x :in *train-data-batches*
                   :for bidx :from 0
                   :for z = (samplez)
                   :do (let ((dlv nil)
                             (dgv nil))
                         ;; discriminator
                         (dotimes (k *k*)
                           (let* ((dr (discriminate x))
                                  (df (discriminate (generate z)))
                                  (l ($data (lossd dr df))))
                             (incf dloss l)
                             (setf dlv l)
                             (optm *discriminator*)
                             ($cg! *discriminator*)
                             ($cg! *generator*)))
                         ;; generator
                         (let* ((df (discriminate (generate z)))
                                (l ($data (lossg df))))
                           (incf gloss l)
                           (setf dgv l)
                           (optm *generator*)
                           ($cg! *discriminator*)
                           ($cg! *generator*))
                         (when (zerop (rem bidx 100))
                           (prn "  D/L:" bidx dlv dgv))))
             (when (zerop (rem epoch 1))
               (let ((g (generate (samplez))))
                 ($cg! *discriminator*)
                 ($cg! *generator*)
                 (loop :for i :from 1 :to 1
                       :for s = (random *batch-size*)
                       :for fname = (format nil "~A/i~A-~A.png" *output* epoch i)
                       :do (outpng ($index ($data g) 0 s) fname))))
             (prn " LOSS:" epoch (/ dloss (* *k* *train-count*)) (/ gloss *train-count*)))))

(defun outpngs (data49 fname &optional (w 28) (h 28))
  (let* ((n 4)
         (img (opticl:make-8-bit-gray-image (* n w) (* n h)))
         (datas (mapcar (lambda (data) ($reshape data w h)) data49)))
    (loop :for i :from 0 :below n
          :do (loop :for j :from 0 :below n
                    :for sx = (* j w)
                    :for sy = (* i h)
                    :for d = ($ datas (+ (* j n) i))
                    :do (loop :for i :from 0 :below h
                              :do (loop :for j :from 0 :below w
                                        :do (progn
                                              (setf (aref img (+ sx i) (+ sy j))
                                                    (round (* 255 ($ d i j)))))))))
    (opticl:write-png-file fname img)))

;; generate samples
(let ((generated (generate (samplez))))
  (outpngs (loop :for i :from 0 :below 16
                 :collect ($index ($data generated) 0 i))
           (format nil "~A/49.png" *output*))
  ($cg! *discriminator*)
  ($cg! *generator*))

(setf *mnist* nil
      *mnist-train-image-batches* nil
      *train-data-batches* nil)

(gcf)
