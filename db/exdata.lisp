(defpackage :th.ex.data
  (:use #:common-lisp
        #:mu
        #:th)
  (:export #:text-lines
           #:ptb
           #:addition
           #:date-data
           #:eng-fra-small
           #:eng-fra-small-processed
           #:iris))

(in-package :th.ex.data)

(defun data-filename (name)
  ($concat (namestring (asdf:system-source-directory :th)) "data/" name))

(defun text-lines (&optional (file :tiny-shakespeare))
  (cond ((eq file :tiny-shakespeare) (read-lines-from (data-filename "tinyshakespeare.txt")))
        ((eq file :obama) (read-lines-from (data-filename "obama.txt")))
        ((eq file :pg) (read-lines-from (data-filename "pg.txt")))
        ((eq file :small-pg) (read-lines-from (data-filename "pgsmall.txt")))))

(defun ptb (&optional (type :train))
  (mapcar (lambda (line) (strim (concatenate 'string line "<eos>")))
          (read-lines-from (data-filename
                            (concatenate 'string
                                         "ptb."
                                         (string-downcase (symbol-name type))
                                         ".txt")))))

(defun addition () (read-lines-from (data-filename "addition.txt")))
(defun date-data () (read-lines-from (data-filename "date.txt")))
(defun eng-fra-small () (read-lines-from (data-filename "eng-fra.small.txt")))
(defun eng-fra-small-processed ()
  (->> (read-lines-from (data-filename "eng-fra.small-processed.txt"))
       (mapcar (lambda (s) (split #\Tab s)))))

(defun iris ()
  (let ((x (tensor 150 4))
        (y (zeros 150 3)))
    (loop :for line :in (cdr (read-lines-from (data-filename "iris.csv")))
          :for i :from 0
          :for parts = (split #\, line)
          :do (let ((xs (mapcar (lambda (s) (parse-float s)) (subseq parts 0 4)))
                    (yloc (parse-integer ($ parts 4))))
                (setf ($ x i 0) ($ xs 0)
                      ($ x i 1) ($ xs 1)
                      ($ x i 2) ($ xs 2)
                      ($ x i 3) ($ xs 3))
                (setf ($ y i yloc) 1)))
    (list :x x :y y
          :targets '("setosa" "versicolor" "virginica")
          :features '("sepal length (cm)" "sepal width (cm)"
                      "petal length (cm)" "petal width (cm)"))))
