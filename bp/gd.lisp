(declaim (optimize (speed 3) (debug 1) (safety 0)))

(in-package :th)

(defgeneric $gd! (node &optional learning-rate) (:documentation "Executes gradient descent."))
(defgeneric $mgd! (node &optional learning-rate momentum) (:documentation "Executes momentum."))
(defgeneric $agd! (node &optional learning-rate) (:documentation "Executes adagrad."))
(defgeneric $amgd! (node &optional learning-rate β1 β2) (:documentation "Executes adam."))
(defgeneric $rmgd! (node &optional learning-rate decay-rate) (:documentation "Executes rmsprop."))
(defgeneric $adgd! (node &optional learning-rate decay-rate) (:documentation "Executes adadelta."))
(defgeneric $rpgd! (node &optional learning-rate etas steps) (:documentation "Executes Rprop."))

(defmethod $gd! ((object t) &optional (learning-rate 0.01)) (declare (ignore learning-rate)))

(defmethod $gd! ((node node) &optional (learning-rate 0.01))
  (let ((data ($data node))
        (grv ($gradient node)))
    (cond ((null grv) nil)
          ((numberp grv) (setf ($data node) (- data (* grv learning-rate))))
          (t ($axpy! (- learning-rate) grv data)))
    ($cg! node)))

(defmethod $gd! ((nodes list) &optional (learning-rate 0.01))
  (loop :for n :in nodes :do ($gd! n learning-rate)))

(defmethod $gd! ((parameters parameters) &optional (learning-rate 0.01))
  (loop :for p :in ($parameters parameters) :do ($gd! p learning-rate)))

(defmethod $mgd! ((object t) &optional (learning-rate 0.01) (momentum 0.9))
  (declare (ignore learning-rate momentum)))

(defmethod $mgd! ((node node) &optional (learning-rate 0.01) (momentum 0.9))
  (let ((data ($data node))
        (grv ($gradient node)))
    (cond ((null grv) nil)
          ((numberp grv) (let ((v ($attr node :v 0)))
                           (setf v (+ (* grv (- learning-rate)) (* v momentum)))
                           (setf ($data node) (+ data v))
                           (setf ($attr node :v) v)))
          (t (let ((v ($attr node :v (apply #'zeros ($size grv)))))
               (setf ($ ($attrs node) :v) ($axpy! (- learning-rate) grv ($mul! v momentum)))
               ($axpy! 1 ($ ($attrs node) :v) data))))
    ($cg! node)))

(defmethod $mgd! ((nodes list) &optional (learning-rate 0.01) (momentum 0.9))
  (loop :for n :in nodes :do ($mgd! n learning-rate momentum)))

(defmethod $mgd! ((parameters parameters) &optional (learning-rate 0.01) (momentum 0.9))
  (loop :for n :in ($parameters parameters) :do ($mgd! n learning-rate momentum)))

(defmethod $agd! ((object t) &optional (learning-rate 0.01))
  (declare (ignore learning-rate)))

(defmethod $agd! ((node node) &optional (learning-rate 0.01))
  (let ((data ($data node))
        (grv ($gradient node))
        (eps 1E-8))
    (cond ((null grv) nil)
          ((numberp grv) (let ((h ($attr node :h 0)))
                           (setf h (+ (* grv grv) h))
                           (setf ($data node) (- data (* learning-rate
                                                         (/ grv (+ (sqrt h) eps)))))
                           (setf ($attr node :h) h)))
          (t (let ((h ($attr node :h (apply #'zeros ($size grv)))))
               ($axpy! 1 ($expt grv 2) h)
               ($axpy! (- learning-rate) ($div grv ($add! ($sqrt h) eps)) data))))
    ($cg! node)))

(defmethod $agd! ((nodes list) &optional (learning-rate 0.01))
  (loop :for n :in nodes :do ($agd! n learning-rate)))

(defmethod $agd! ((parameters parameters) &optional (learning-rate 0.01))
  (loop :for n :in ($parameters parameters) :do ($agd! n learning-rate)))

(defmethod $amgd! ((object t) &optional (learning-rate 0.001) (β1 0.9) (β2 0.999))
  (declare (ignore learning-rate β1 β2)))

(defmethod $amgd! ((node node) &optional (learning-rate 0.001) (β1 0.9) (β2 0.999))
  (let ((data ($data node))
        (grv ($gradient node)))
    (cond ((null grv) nil)
          ((numberp grv) (let ((niter ($attr node :niteration 1))
                               (m ($attr node :m 0))
                               (v ($attr node :v 0)))
                           (setf m (+ (* β1 m) (* (- 1 β1) grv)))
                           (setf v (+ (* β1 v) (* (- 1 β1) (* grv grv))))
                           (setf ($attr node :m) m)
                           (setf ($attr node :v) v)
                           (setf ($attr node :niteration) (1+ niter))
                           (setf m (/ m (- 1 (expt β1 niter))))
                           (setf v (/ v (- 1 (expt β2 niter))))
                           (setf ($data node) (- data (/ (* learning-rate m)
                                                         (+ (sqrt v) 1E-8))))))
          (t (let ((niter ($attr node :niteration 1))
                   (m ($attr node :m (apply #'zeros ($size grv))))
                   (v ($attr node :v (apply #'zeros ($size grv))))
                   (clr 0))
               (setf ($attr node :niteration) (1+ niter))
               (setf clr (/ (* learning-rate (sqrt (- 1 (expt β2 niter))))
                            (- 1 (expt β1 niter))))
               ($axpy! (- 1 β1) ($sub grv m) m)
               ($axpy! (- 1 β2) ($sub! ($expt grv 2) v) v)
               ($axpy! (- clr) ($div m ($add! ($sqrt v) 1E-8)) data))))
    ($cg! node)))

(defmethod $amgd! ((nodes list) &optional (learning-rate 0.001) (β1 0.9) (β2 0.999))
  (loop :for n :in nodes :do ($amgd! n learning-rate β1 β2)))

(defmethod $amgd! ((parameters parameters) &optional (learning-rate 0.001) (β1 0.9) (β2 0.999))
  (loop :for n :in ($parameters parameters) :do ($amgd! n learning-rate β1 β2)))

(defmethod $rmgd! ((object t) &optional (learning-rate 0.001) (decay-rate 0.99))
  (declare (ignore learning-rate decay-rate)))

(defmethod $rmgd! ((node node) &optional (learning-rate 0.001) (decay-rate 0.99))
  (let ((data ($data node))
        (grv ($gradient node))
        (eps 1E-8))
    (cond ((null grv) nil)
          ((numberp grv) (let ((h ($attr node :h 0)))
                           (setf h (* h decay-rate))
                           (setf h (+ h (* (- 1 decay-rate) grv grv)))
                           (setf ($attr node :h) h)
                           (setf ($data node) (- data (/ (* learning-rate grv)
                                                         (+ (sqrt h) eps))))))
          (t (let ((h ($attr node :h (apply #'zeros ($size grv)))))
               ($mul! h decay-rate)
               ($axpy! (- 1 decay-rate) ($expt grv 2) h)
               ($axpy! (- learning-rate) ($div grv ($add! ($sqrt h) eps)) data))))
    ($cg! node)))

(defmethod $rmgd! ((nodes list) &optional (learning-rate 0.001) (decay-rate 0.99))
  (loop :for n :in nodes :do ($rmgd! n learning-rate decay-rate)))

(defmethod $rmgd! ((parameters parameters) &optional (learning-rate 0.001) (decay-rate 0.99))
  (loop :for n :in ($parameters parameters) :do ($rmgd! n learning-rate decay-rate)))

(defmethod $adgd! ((object t) &optional (learning-rate 1) (decay-rate 0.95))
  (declare (ignore learning-rate decay-rate)))

(defmethod $adgd! ((node node) &optional (learning-rate 1) (decay-rate 0.95))
  (let ((data ($data node))
        (grv ($gradient node))
        (eps 1E-8))
    (cond ((null grv) nil)
          ((numberp grv) (let ((h ($attr node :h 0))
                               (d ($attr node :d 0)))
                           (setf h (* h decay-rate))
                           (setf h (+ h (* (- 1 decay-rate) grv grv)))
                           (let ((delta (* grv (/ (sqrt (+ d eps))
                                                  (sqrt (+ h eps))))))
                             (setf d (* d decay-rate))
                             (setf d (+ d (* (- 1 decay-rate) (* delta delta))))
                             (setf ($attr node :h) h)
                             (setf ($attr node :d) d)
                             (setf ($data node) (- data (* learning-rate delta))))))
          (t (let ((h ($attr node :h (apply #'zeros ($size grv))))
                   (d ($attr node :d (apply #'zeros ($size grv)))))
               ($mul! h decay-rate)
               ($axpy! (- 1 decay-rate) ($expt grv 2) h)
               (let ((delta ($mul! ($sqrt! ($div! ($add d eps) ($add h eps))) grv)))
                 ($mul! d decay-rate)
                 ($axpy! (- 1 decay-rate) ($expt delta 2) d)
                 ($axpy! -1 ($mul! delta learning-rate) data)))))
    ($cg! node)))

(defmethod $adgd! ((nodes list) &optional (learning-rate 1) (decay-rate 0.95))
  (loop :for n :in nodes :do ($adgd! n learning-rate decay-rate)))

(defmethod $adgd! ((parameters parameters) &optional (learning-rate 1) (decay-rate 0.95))
  (loop :for n :in ($parameters parameters) :do ($adgd! n learning-rate decay-rate)))

(defmethod $rpgd! ((node node) &optional (learning-rate 1E-2) (etas '(0.5 1.2)) (steps '(1E-6 50)))
  (let ((data ($data node))
        (grv ($gradient node))
        (eta-minus (car etas))
        (eta-plus (cadr etas))
        (step-size-min (car steps))
        (step-size-max (cadr steps)))
    (cond ((null grv) nil)
          ((numberp grv) (let* ((step ($attr node :step 0))
                                (prev ($attr node :prev 0))
                                (step-size ($attr node :step-size learning-rate))
                                (sign (signum (* prev grv))))
                           (setf ($attr node :step) (1+ step))
                           (cond ((> sign 0) (setf sign eta-plus))
                                 ((< sign 0) (setf sign eta-minus))
                                 (T (setf sign 1)))
                           (setf step-size (* step-size sign))
                           (when (> step-size step-size-max)
                             (setf step-size step-size-max))
                           (when (< step-size step-size-min)
                             (setf step-size step-size-min))
                           (setf ($attr node :step-size) step-size)
                           (let ((grd grv))
                             (when (eq sign eta-minus) (setf grd 0))
                             (setf ($data node) (- data (* (signum grd) step-size)))
                             (setf ($attr node :prev) grd))))
          (T (let* ((step ($attr node :step 0))
                    (prev ($attr node :prev ($zero data)))
                    (step-size ($attr node :step-size ($fill! ($zero grv) learning-rate)))
                    (sign ($sign ($mul prev grv))))
               (setf ($attr node :step) (1+ step))
               (setf ($ sign ($gt sign 0)) eta-plus)
               (setf ($ sign ($lt sign 0)) eta-minus)
               (setf ($ sign ($eq sign 0)) 1)
               ($clamp! ($mul! step-size sign) step-size-min step-size-max)
               (setf ($attr node :step-size) step-size)
               (let ((grd ($clone grv)))
                 (setf ($ grd ($eq sign eta-minus)) 0)
                 ($axpy! -1 ($mul ($sign grd) step-size) data)
                 (setf ($attr node :prev) grd)))))
    ($cg! node)))

(defmethod $rpgd! ((nodes list) &optional (learning-rate 1E-2) (etas '(0.5 1.2))
                                  (steps '(1E-6 50)))
  (loop :for n :in nodes :do ($rpgd! n learning-rate etas steps)))

(defmethod $rpgd! ((parameters parameters) &optional (learning-rate 1E-2) (etas '(0.5 1.2))
                                             (steps '(1E-6 50)))
  (loop :for n :in ($parameters parameters) :do ($rpgd! n learning-rate etas steps)))
