(declaim (optimize (speed 3) (debug 0) (safety 0)))

(in-package :th)

(defun abs-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       (let ((d ($empty ($data x))))
                                         (nn-abs-update-grad-input ($data x) gradient d)
                                         ($bp! x d))
                                       x)))))
  node)

(defmethod $abs ((x node))
  (let ((out ($empty ($data x))))
    (nn-abs-update-output ($data x) out)
    (let ((result (node out)))
      (setf ($name result) "ABS")
      (setf ($children result) x)
      (setf ($gradientp result) ($gradientp x))
      (setf ($bpfn result) #'abs-backprop)
      result)))

(defun acos-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($div -1 ($sqrt ($sub 1 ($expt ($data x) 2)))))
                                       x)))))
  node)

(defmethod $acos ((x node))
  (let ((result (node ($acos ($data x)))))
    (setf ($name result) "ACOS")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'acos-backprop)
    result))

(defun asin-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($div 1 ($sqrt ($sub 1 ($expt ($data x) 2)))))
                                       x)))))
  node)

(defmethod $asin ((x node))
  (let ((result (node ($asin ($data x)))))
    (setf ($name result) "ASIN")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'asin-backprop)
    result))

(defun atan-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($div 1 ($add 1 ($expt ($data x) 2))))
                                       x)))))
  node)

(defmethod $atan ((x node))
  (let ((result (node ($atan ($data x)))))
    (setf ($name result) "ATAN")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'atan-backprop)
    result))

(defun atan2-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((y ($c0 node))
                                 (x ($c1 node)))
                             (list (if ($gradientp y)
                                       ($bp! y ($div x ($add ($expt ($data x) 2)
                                                             ($expt ($data y) 2))))
                                       y)
                                   (if ($gradientp x)
                                       ($bp! x ($div ($neg y) ($add ($expt ($data x) 2)
                                                                    ($expt ($data y) 2))))
                                       x)))))
  node)

(defmethod $atan2 ((y node) (x node))
  (let ((result (node ($atan2 ($data y) ($data x)))))
    (setf ($name result) "ATAN2")
    (setf ($children result) (list y x))
    (setf ($gradientp result) (or ($gradientp y) ($gradientp x)))
    (setf ($bpfn result) #'atan2-backprop)
    result))

(defun cos-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($mul! ($neg ($sin ($data x))) gradient))
                                       x)))))
  node)

(defmethod $cos ((x node))
  (let ((result (node ($cos ($data x)))))
    (setf ($name result) "COS")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'cos-backprop)
    result))

(defun cosh-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($mul ($sinh ($data x)) gradient))
                                       x)))))
  node)

(defmethod $cosh ((x node))
  (let ((result (node ($cosh ($data x)))))
    (setf ($name result) "COSH")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'cosh-backprop)
    result))

(defun exp-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($mul ($data node) gradient))
                                       x)))))
  node)

(defmethod $exp ((x node))
  (let ((result (node ($exp ($data x)))))
    (setf ($name result) "EXP")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'exp-backprop)
    result))

(defun expt-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((a ($c0 node))
                                 (b ($c1 node)))
                             (list (if ($gradientp a)
                                       ($bp! a ($mul! ($mul gradient ($data b))
                                                      ($expt ($data a) ($- ($data b) 1))))
                                       a)
                                   (if ($gradientp b)
                                       ($bp! b ($mul! ($mul! ($log ($data a))
                                                             ($expt ($data a) ($data b)))
                                                      gradient))
                                       b)))))
  node)

(defmethod $expt ((a node) (b node))
  (let ((result (node ($expt ($data a) ($data b)))))
    (setf ($name result) "EXPT")
    (setf ($children result) (list a b))
    (setf ($gradientp result) (or ($gradientp a) ($gradientp b)))
    (setf ($bpfn result) #'expt-backprop)
    result))

(defmethod $expt ((a node) (b number))
  (let ((result (node ($expt ($data a) b))))
    (setf ($children result) (list a ($constant b)))
    (setf ($gradientp result) ($gradientp a))
    (setf ($bpfn result) #'expt-backprop)
    result))

(defun dlog (x) ($div 1.0 x))

(defun log-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($* (dlog ($data x)) gradient))
                                       x)))))
  node)

(defmethod $log ((x node))
  (let ((result (node ($log ($data x)))))
    (setf ($name result) "LOG")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'log-backprop)
    result))

(defun sin-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($mul! ($cos ($data x)) gradient))
                                       x)))))
  node)

(defmethod $sin ((x node))
  (let ((result (node ($sin ($data x)))))
    (setf ($name result) "SIN")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'sin-backprop)
    result))

(defun dsigmoid (s) ($mul s ($sub 1 s)))

(defun sigmoid-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($mul! (dsigmoid ($data node)) gradient))
                                       x)))))
  node)

(defmethod $sigmoid ((x node))
  (let ((result (node ($sigmoid ($data x)))))
    (setf ($name result) "SIGMOID")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'sigmoid-backprop)
    result))

(defun sinh-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($mul ($cosh ($data x)) gradient))
                                       x)))))
  node)

(defmethod $sinh ((x node))
  (let ((result (node ($sinh ($data x)))))
    (setf ($name result) "SINH")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'sinh-backprop)
    result))

(defun sqrt-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($mul! ($mul gradient 0.5)
                                                      ($expt ($data x) -0.5)))
                                       x)))))
  node)

(defmethod $sqrt ((x node))
  (let ((result (node ($sqrt ($data x)))))
    (setf ($name result) "SQRT")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'sqrt-backprop)
    result))

(defun tan-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($mul! ($expt ($cos ($data x)) 2.0) gradient))
                                       x)))))
  node)

(defmethod $tan ((x node))
  (let ((result (node ($tan ($data x)))))
    (setf ($name result) "TAN")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'tan-backprop)
    result))

(defun dtanh (s) ($sub 1 ($* s s)))

(defun tanh-backprop (node gradient)
  (setgradient node gradient)
  (setf ($children node) (when ($children node)
                           (let ((x ($c0 node)))
                             (list (if ($gradientp x)
                                       ($bp! x ($mul! (dtanh ($data node)) gradient))
                                       x)))))
  node)

(defmethod $tanh ((x node))
  (let ((result (node ($tanh ($data x)))))
    (setf ($name result) "TANH")
    (setf ($children result) (list x))
    (setf ($gradientp result) ($gradientp x))
    (setf ($bpfn result) #'tanh-backprop)
    result))
