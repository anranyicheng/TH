(defpackage :challenger-accident
  (:use #:common-lisp
        #:mu
        #:th
        #:th.pp))

(in-package :challenger-accident)

(defparameter *data* (->> (slurp "./data/challenger.csv")
                          (cdr)
                          (mapcar (lambda (line)
                                    (let ((ss (split #\, line)))
                                      (list (parse-integer ($1 ss))
                                            (parse-integer ($2 ss) :junk-allowed T)))))
                          (filter (lambda (rec)
                                    (and (car rec) (cadr rec))))))

(defparameter *temperature* (tensor (mapcar #'car *data*)))
(defparameter *failure* (tensor (mapcar #'cadr *data*)))

(defun p (temperature alpha beta)
  ($sigmoid ($neg ($add ($mul temperature beta) alpha))))

(defun posterior (alpha beta)
  (let ((prior-alpha (score/normal alpha 0 1000.0))
        (prior-beta (score/normal beta 0 1000.0)))
    (when (and prior-alpha prior-beta)
      (let ((l (score/bernoulli *failure* (p *temperature* alpha beta))))
        (when l
          ($+ prior-alpha prior-beta l))))))

(let ((traces (mcmc/mh '(0.0 0.0) #'posterior :type :sc)))
  (prn traces))

;; though with above posterior function, my code emits proper results.
;; however, the book, Bayesian Methods for Hackers uses fitting first.
;; and with thr fitting result as the starting point, samples again.

;; MAP - to fit alpha beta properly
(prn (map/fit #'posterior '(0.0 0.0)))

(defun posterior (alpha beta)
  (let ((prior-alpha (score/normal alpha -15.05 100.0))
        (prior-beta (score/normal beta 0.23 1.0)))
    (when (and prior-alpha prior-beta)
      (let ((l (score/bernoulli *failure* (p *temperature* alpha beta))))
        (when l
          ($+ prior-alpha prior-beta l))))))

(let ((traces (mcmc/mh '(0.0 0.0) #'posterior :type :sc)))
  (prn traces))
