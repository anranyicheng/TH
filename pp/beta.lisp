(in-package :th.pp)

(defgeneric ll/beta (data alpha beta))
(defgeneric sample/beta (alpha beta &optional n))

(defun of-beta-p (data alpha beta)
  (and (of-unit-interval-p data) (of-plusp alpha) (of-plusp beta)))

(defmethod ll/beta ((data number) (alpha number) (beta number))
  (when (of-beta-p data alpha beta)
    (+ (* (- alpha 1) (log data))
       (* (- beta 1) (log (- 1 data)))
       (- ($lbetaf alpha beta)))))

(defmethod ll/beta ((data number) (alpha node) (beta number))
  (when (of-beta-p data ($data alpha) beta)
    ($sub ($add ($mul ($sub alpha 1) (log data))
                (* (- beta 1) (log (- 1 data))))
          ($lbetaf alpha beta))))

(defmethod ll/beta ((data number) (alpha number) (beta node))
  (when (of-beta-p data alpha ($data beta))
    ($sub ($add (* (- alpha 1) (log data))
                ($mul ($sub beta 1) (log (- 1 data))))
          ($lbetaf alpha beta))))

(defmethod ll/beta ((data number) (alpha node) (beta node))
  (when (of-beta-p data ($data alpha) ($data beta))
    ($sub ($add ($mul ($sub alpha 1) (log data))
                ($mul ($sub beta 1) (log (- 1 data))))
          ($lbetaf alpha beta))))

(defmethod ll/beta ((data tensor) (alpha number) (beta number))
  (when (of-beta-p data alpha beta)
    ($sum ($sub ($add ($mul (- alpha 1) ($log data))
                      ($mul (- beta 1) ($log ($sub 1 data))))
                ($lbetaf alpha beta)))))

(defmethod ll/beta ((data tensor) (alpha node) (beta number))
  (when (of-beta-p data ($data alpha) beta)
    ($sum ($sub ($add ($mul ($sub alpha 1) ($log data))
                      ($mul (- beta 1) ($log ($sub 1 data))))
                ($lbetaf alpha beta)))))

(defmethod ll/beta ((data tensor) (alpha number) (beta node))
  (when (of-beta-p data alpha ($data beta))
    ($sum ($sub ($add ($mul (- alpha 1) ($log data))
                      ($mul ($sub beta 1) ($log ($sub 1 data))))
                ($lbetaf alpha beta)))))

(defmethod ll/beta ((data tensor) (alpha node) (beta node))
  (when (of-beta-p data ($data alpha) ($data beta))
    ($sum ($sub ($add ($mul ($sub alpha 1) ($log data))
                      ($mul ($sub beta 1) ($log ($sub 1 data))))
                ($lbetaf alpha beta)))))

(defmethod sample/beta ((alpha number) (beta number) &optional (n 1))
  (cond ((= n 1) (random/beta alpha beta))
        ((> n 1) ($beta! (tensor n) alpha beta))))

(defmethod sample/beta ((alpha node) (beta number) &optional (n 1))
  (cond ((= n 1) (random/beta ($data alpha) beta))
        ((> n 1) ($beta! (tensor n) ($data alpha) beta))))

(defmethod sample/beta ((alpha number) (beta node) &optional (n 1))
  (cond ((= n 1) (random/beta alpha ($data beta)))
        ((> n 1) ($beta! (tensor n) alpha ($data beta)))))

(defmethod sample/beta ((alpha node) (beta node) &optional (n 1))
  (cond ((= n 1) (random/beta ($data alpha) ($data beta)))
        ((> n 1) ($beta! (tensor n) ($data alpha) ($data beta)))))
