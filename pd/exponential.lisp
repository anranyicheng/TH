(in-package :th)

(defgeneric score/exponential (data rate))
(defgeneric sample/exponential (rate &optional n))

(defun of-exponential-p (data rate) (and (of-ge data 0) (of-plusp rate)))

(defmethod score/exponential ((data number) (rate number))
  (when (of-exponential-p data rate)
    (- (log rate) (* rate data))))

(defmethod score/exponential ((data number) (rate node))
  (when (of-exponential-p data ($data rate))
    ($sub ($log rate) ($mul rate data))))

(defmethod score/exponential ((data tensor) (rate number))
  (when (of-exponential-p data rate)
    ($sum ($sub ($log rate) ($mul rate data)))))

(defmethod score/exponential ((data tensor) (rate node))
  (when (of-exponential-p data ($data rate))
    ($sum ($sub ($log rate) ($mul rate data)))))

(defmethod score/exponential ((data node) (rate number))
  (when (of-exponential-p ($data data) rate)
    ($sum ($sub ($log rate) ($mul rate data)))))

(defmethod score/exponential ((data node) (rate node))
  (when (of-exponential-p ($data data) ($data rate))
    ($sum ($sub ($log rate) ($mul rate data)))))

(defmethod sample/exponential ((rate number) &optional (n 1))
  (cond ((= n 1) (random/exponential rate))
        ((> n 1) ($exponential! (tensor n) rate))))

(defmethod sample/exponential ((rate node) &optional (n 1))
  (cond ((= n 1) (random/exponential ($data rate)))
        ((> n 1) ($exponential! (tensor n) ($data rate)))))
