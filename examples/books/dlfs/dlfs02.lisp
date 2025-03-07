(defpackage :dlfs-02
  (:use #:common-lisp
        #:mu
        #:th))

(in-package :dlfs-02)

(defun and-gate (x1 x2)
  (let ((w1 0.5)
        (w2 0.5)
        (theta 0.7))
    (let ((tmp (+ (* x1 w1) (* x2 w2))))
      (cond ((<= tmp theta) 0)
            ((> tmp theta) 1)))))

(prn (and-gate 0 0))
(prn (and-gate 1 0))
(prn (and-gate 0 1))
(prn (and-gate 1 1))

(defun and-gate (x1 x2)
  (let ((x (tensor (list x1 x2)))
        (w (tensor '(0.5 0.5)))
        (b -0.7))
    (let ((tmp ($+ ($sum ($* w x)) b)))
      (if (<= tmp 0) 0 1))))

(prn (and-gate 0 0))
(prn (and-gate 1 0))
(prn (and-gate 0 1))
(prn (and-gate 1 1))

(defun nand-gate (x1 x2)
  (let ((x (tensor (list x1 x2)))
        (w (tensor '(-0.5 -0.5)))
        (b 0.7))
    (let ((tmp ($+ ($sum ($* w x)) b)))
      (if (<= tmp 0) 0 1))))

(prn (nand-gate 0 0))
(prn (nand-gate 1 0))
(prn (nand-gate 0 1))
(prn (nand-gate 1 1))

(defun or-gate (x1 x2)
  (let ((x (tensor (list x1 x2)))
        (w (tensor '(0.5 0.5)))
        (b -0.2))
    (let ((tmp ($+ ($sum ($* w x)) b)))
      (if (<= tmp 0) 0 1))))

(prn (or-gate 0 0))
(prn (or-gate 1 0))
(prn (or-gate 0 1))
(prn (or-gate 1 1))

(defun xor-gate (x1 x2)
  (let ((s1 (nand-gate x1 x2))
        (s2 (or-gate x1 x2)))
    (and-gate s1 s2)))

(prn (xor-gate 0 0))
(prn (xor-gate 1 0))
(prn (xor-gate 0 1))
(prn (xor-gate 1 1))
