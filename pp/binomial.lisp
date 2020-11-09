(in-package :th.pp)

(defgeneric ll/binomial (data p n))
(defgeneric sample/binomial (p nt &optional n))

(defun of-binomial-p (data p n) (and (of-ie data 0 n) (of-it p 0 1) (> n 0)))

(defun lbc (n k)
  (let ((n1 ($add n 1))
        (k1 ($add k 1))
        (nk1 ($add ($sub n k) 1)))
    ($sub ($lgammaf n1)
          ($add ($lgammaf k1) ($lgammaf nk1)))))

(defmethod ll/binomial ((data number) (p number) (n number))
  (when (of-binomial-p data p n)
    (let ((lbc (lbc n data))
          (lp (log p))
          (lq (log (- 1 p))))
      (+ lbc (+ (* data lp) (* (- n data) lq))))))

(defmethod ll/binomial ((data number) (p node) (n number))
  (when (of-binomial-p data ($data p) n)
    (let ((lbc (lbc n data))
          (lp ($log p))
          (lq ($log ($sub 1 p))))
      ($add lbc ($add ($mul data lp) ($mul (- n data) lq))))))

(defmethod ll/binomial ((data tensor) (p number) (n number))
  (when (of-binomial-p data p n)
    (let ((lbc (lbc n data))
          (lp (log p))
          (lq (log (- 1 p))))
      ($sum ($add lbc ($add ($mul data lp) ($mul ($sub n data) lq)))))))

(defmethod ll/binomial ((data tensor) (p node) (n number))
  (when (of-binomial-p data ($data p) n)
    (let ((lbc (lbc n data))
          (lp ($log p))
          (lq ($log ($sub 1 p))))
      ($sum ($add lbc ($add ($mul data lp) ($mul ($sub n data) lq)))))))

(defmethod sample/binomial ((p number) (nt number) &optional (n 1))
  (cond ((= n 1) (random/binomial nt p))
        ((> n 1) ($binomial! (tensor n) nt p))))

(defmethod sample/binomial ((p node) (nt number) &optional (n 1))
  (cond ((= n 1) (random/binomial nt ($data p)))
        ((> n 1) ($binomial! (tensor n) nt ($data p)))))
