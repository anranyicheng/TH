(declaim (optimize (speed 3) (debug 1) (safety 0)))

(in-package :th)

(defgeneric $logit (p))
(defgeneric $invlogit (x))

(defmethod $logit ((p number))
  (log (/ p (- 1.0 p))))

(defmethod $logit ((p tensor))
  ($log ($div p ($sub 1.0 p))))

(defmethod $logit ((p node))
  (node ($logit ($data p))
        :name :logit
        :link (link (to p ($mul! ($add ($div 1 ($data p)) ($div 1 ($sub 1.0 ($data p))))
                                 gv)))))

(defmethod $invlogit ((x number))
  (/ 1.0 (+ 1.0 (exp (- x)))))

(defmethod $invlogit ((x tensor))
  ($div 1.0 ($add 1.0 ($exp ($neg x)))))

(defmethod $invlogit ((x node))
  (node ($invlogit ($data x))
        :name :invlogit
        :link (link (to x ($mul! ($mul dv ($sub 1 dv)) gv)))))

(defmethod $abs ((x node))
  (let ((out ($clear ($data x))))
    (nn-abs-update-output ($data x) out)
    (node out
          :name :abs
          :link (link (to x (let ((d ($clear ($data x))))
                              (nn-abs-update-grad-input ($data x) gv d)
                              d))))))

(defmethod $acos ((x node))
  (node ($acos ($data x))
        :name :acos
        :link (link (to x ($mul! ($div -1 ($sqrt! ($sub 1 ($expt ($data x) 2)))) gv)))))

(defmethod $asin ((x node))
  (node ($asin ($data x))
        :name :asin
        :link (link
                (to x ($mul! ($neg! ($sqrt! ($cinv! ($neg! ($sub! ($expt ($data x) 2) 1)))))
                                 gv)))))

(defmethod $atan ((x node))
  (node ($atan ($data x))
        :name :atan
        :link (link (to x ($mul! ($cinv! ($add! ($expt ($data x) 2) 1)) gv)))))

(defmethod $atan2 ((y node) (x node))
  (node ($atan2 ($data y) ($data x))
        :name :atan2
        :link (link
                (to y (let ((xd ($data x))
                                (yd ($data y)))
                            ($mul! ($mul! ($cinv! ($add! ($expt xd 2) ($expt yd 2))) xd) gv)))
                (to x (let ((xd ($data x))
                                (yd ($data y)))
                            ($neg! ($mul! ($mul! ($cinv! ($add! ($expt xd 2) ($expt yd 2))) yd)
                                          gv)))))))

(defmethod $cos ((x node))
  (node ($cos ($data x))
        :name :cos
        :link (link (to x ($mul! ($neg! ($sin ($data x))) gv)))))

(defmethod $cosh ((x node))
  (node ($cosh ($data x))
        :name :cosh
        :link (link (to x ($mul! ($sinh ($data x)) gv)))))

(defmethod $exp ((x node))
  (node ($exp ($data x))
        :name :exp
        :link (link (to x ($mul dv gv)))))

(defmethod $expt ((a node) (b node))
  (node ($expt ($data a) ($data b))
        :name :expt
        :link (link
                (to a ($mul! ($mul gv ($data b)) ($expt ($data a) ($- ($data b) 1))))
                (to b ($mul! ($mul! ($log ($data a)) ($expt ($data a) ($data b))) gv)))))

(defmethod $expt ((a node) (b tensor))
  (node ($expt ($data a) b)
        :name :expt
        :link (link (to a ($mul! ($mul! ($expt ($data a) ($- b 1)) gv) b)))))

(defmethod $expt ((a node) (b number))
  (node ($expt ($data a) b)
        :name :expt
        :link (link (to a ($mul! ($mul! ($expt ($data a) (- b 1)) gv) b)))))

(defmethod $expt ((a tensor) (b node))
  (node ($expt a ($data b))
        :name :expt
        :link (link (to b ($mul! ($mul! ($log a) ($expt a ($data b))) gv)))))

(defmethod $expt ((a number) (b node))
  (node ($expt a ($data b))
        :name :expt
        :link (link (to b ($mul! ($mul! ($expt a ($data b)) (log a)) gv)))))

(defun dlog (x) ($cinv x))

(defmethod $log ((x node))
  (node ($log ($data x))
        :name :log
        :link (link (to x ($mul! (dlog ($data x)) gv)))))

(defmethod $log1p ((x node))
  (node ($log1p ($data x))
        :name :log1p
        :link (link (to x ($mul! ($cinv ($+ ($data x) 1)) gv)))))

(defmethod $sin ((x node))
  (node ($sin ($data x))
        :name :sin
        :link (link (to x ($mul! ($cos ($data x)) gv)))))

(defun dsigmoid (s) ($mul! ($sub 1 s) s))

(defmethod $sigmoid ((x node))
  (node ($sigmoid ($data x))
        :name :sigmoid
        :link (link (to x ($mul! (dsigmoid dv) gv)))))

(defmethod $sinh ((x node))
  (node ($sinh ($data x))
        :name :sinh
        :link (link (to x ($mul! ($cosh ($data x)) gv)))))

(defmethod $sqrt ((x node))
  (node ($sqrt ($data x))
        :name :sqrt
        :link (link (to x (let* ((dx ($clear ($data x))))
                            (nn-sqrt-update-grad-input ($data x) gv dx dv)
                            dx)))))

(defmethod $tan ((x node))
  (node ($tan ($data x))
        :name :tan
        :link (link (to x (let* ((dx ($clear ($data x))))
                            (nn-tanh-update-grad-input gv dx dv)
                            dx)))))

(defun dtanh (s) ($neg! ($sub! ($mul s s) 1)))

(defmethod $tanh ((x node))
  (node ($tanh ($data x))
        :name :tanh
        :link (link (to x ($mul! (dtanh dv) gv)))))

(defmethod $sign ((x node))
  (node ($sign ($data x))
        :name :sign
        :link (link (to x ($zero gv)))))

(defgeneric $square (x) (:documentation "Square function."))

(defmethod $square ((x number)) (* x x))

(defmethod $square ((x tensor))
  (let ((output ($clear x)))
    (nn-square-update-output x output)
    output))

(defmethod $square ((x node))
  (if ($tensorp ($data x))
      (node ($square ($data x))
            :name :square
            :link (link (to x (let ((dx ($clear ($data x))))
                                (nn-square-update-grad-input ($data x) gv dx)
                                dx))))
      (node ($square ($data x))
            :name :square
            :link (link (to x (* 2 ($data x) gv))))))

(defmethod $gammaf ((x number))
  (let ((xt (tensor.float (list x))))
    ($scalar ($gammaf xt))))

(defmethod $gammaf ((x node))
  (node ($gammaf ($data x))
        :name :gammaf
        :link (link (to x ($mul! ($mul dv ($polygamma ($data x) 0)) gv)))))

(defmethod $lgammaf ((x number))
  (let ((xt (tensor.float (list x))))
    ($scalar ($lgammaf xt))))

(defmethod $lgammaf ((x node))
  (node ($lgammaf ($data x))
        :name :lgammaf
        :link (link (to x ($mul! ($polygamma ($data x) 0) gv)))))

(defmethod $betaf ((x number) (y number))
  (let ((xt (tensor.double (list x)))
        (yt (tensor.double (list y))))
    ($scalar ($betaf xt yt))))

(defmethod $betaf ((x node) (y node))
  (node ($betaf ($data x) ($data y))
        :name :betaf
        :link (link
                (to x ($mul! ($mul dv ($sub ($polygamma ($data x) 0)
                                            ($polygamma ($add ($data x) ($data y)) 0)))
                             gv))
                (to y ($mul! ($mul dv ($sub ($polygamma ($data y) 0)
                                            ($polygamma ($add ($data x) ($data y)) 0)))
                             gv)))))

(defmethod $lbetaf ((x number) (y number))
  (let ((xt (tensor.double (list x)))
        (yt (tensor.double (list y))))
    ($scalar ($lbetaf xt yt))))

(defmethod $lbetaf ((x node) (y node))
  (node ($lbetaf ($data x) ($data y))
        :name :lbetaf
        :link (link
                (to x ($mul! ($sub ($polygamma ($data x) 0)
                                   ($polygamma ($add ($data x) ($data y)) 0))
                             gv))
                (to y ($mul! ($sub ($polygamma ($data y) 0)
                                   ($polygamma ($add ($data x) ($data y)) 0))
                             gv)))))

(defmethod $lbetaf ((x node) (y number))
  (node ($lbetaf ($data x) y)
        :name :lbetaf
        :link (link
                (to x ($mul! ($sub ($polygamma ($data x) 0)
                                   ($polygamma ($add ($data x) y) 0))
                             gv)))))

(defmethod $lbetaf ((x number) (y node))
  (node ($lbetaf x ($data y))
        :name :lbetaf
        :link (link
                (to y ($mul! ($sub ($polygamma ($data y) 0)
                                   ($polygamma ($add x ($data y)) 0))
                             gv)))))

(defmethod $erf ((x number))
  (let ((xt (tensor.double (list x))))
    ($scalar ($erf xt))))

(defmethod $erf ((x node))
  (node ($erf ($data x))
        :name :erf
        :link (link (to x ($mul! ($mul (/ 2 (sqrt pi)) ($exp ($- ($square x)))) gv)))))

(defmethod $erfc ((x number))
  (let ((xt (tensor.double (list x))))
    ($scalar ($erfc xt))))

(defmethod $erfc ((x node))
  (node ($erf ($data x))
        :name :erfc
        :link (link (to x ($mul! ($mul (/ -2 (sqrt pi)) ($exp ($- ($square x)))) gv)))))

(defgeneric $relu (x) (:documentation "RELU activation function."))
(defgeneric $lrelu (x &optional nv) (:documentation "Leaky RELU activation function."))
(defgeneric $elu (x &optional α) (:documentation "Exponential LU activation function."))
(defgeneric $selu (x) (:documentation "Scaled exponential LU activiation function."))
(defgeneric $softmax (x) (:documentation "Softmax function."))
(defgeneric $logsoftmax (x) (:documentation "Log softmax function."))
(defgeneric $softplus (x) (:documentation "Softplus function."))
(defgeneric $mish (x) (:documentation "self regularized non-monotonic activation function."))
(defgeneric $swish (x) (:documentation "swish activation function."))
(defgeneric $gelu (x) (:documentation "gaussian error linear units activation function."))
(defgeneric $celu (x &optional α) (:documentation "continuously differentiable exponential LU."))

(defmethod $relu ((x number)) (max 0 x))

(defmethod $relu ((x tensor))
  (let ((output ($clear x)))
    (nn-threshold-update-output x output 0 0 nil)
    output))

(defun drelu (input gradient)
  (let ((dinput ($clear input)))
    (nn-threshold-update-grad-input input gradient dinput 0 0 nil)
    dinput))

(defmethod $relu ((x node))
  (node ($relu ($data x))
        :name :relu
        :link (link (to x (drelu ($data x) gv)))))

(defmethod $lrelu ((x number) &optional (nv 0.01)) (max (* nv x) x))

(defmethod $lrelu ((x tensor) &optional (nv 0.01))
  (let ((output ($clear x)))
    (nn-leaky-relu-update-output x output nv nil)
    output))

(defun dlrelu (input gradient &optional (nv 0.01))
  (let ((dinput ($clear input)))
    (nn-leaky-relu-update-grad-input input gradient dinput nv nil)
    dinput))

(defmethod $lrelu ((x node) &optional (nv 0.01))
  (node ($lrelu ($data x) nv)
        :name :lrelu
        :link (link (to x (dlrelu ($data x) gv nv)))))

(defmethod $elu ((x number) &optional (α 1))
  (if (<= x 0)
      (* α (- (exp x) 1))
      x))

(defmethod $elu ((x tensor) &optional (α 1))
  (let ((output ($clear x)))
    (nn-elu-update-output x output α nil)
    output))

(defun delu (input output gradient &optional (alpha 1))
  (let ((dinput ($clear output)))
    (nn-elu-update-grad-input input gradient dinput output alpha nil)
    dinput))

(defmethod $elu ((x node) &optional (α 1))
  (node ($elu ($data x) α)
        :name :elu
        :link (link (to x (delu ($data x) dv gv α)))))

(defmethod $selu ((x number))
  (let ((alpha 1.6732632423543772848170429916717)
        (scale 1.0507009873554804934193349852946))
    (* ($elu x alpha) scale)))

(defmethod $selu ((x tensor))
  (let ((alpha 1.6732632423543772848170429916717)
        (scale 1.0507009873554804934193349852946)
        (output ($clear x)))
    (nn-selu-update-output x output alpha scale nil)
    output))

(defun dselu (input output gradient &optional (alpha 1) (scale 1))
  (let ((dinput ($clear output)))
    (nn-selu-update-grad-input input gradient dinput output alpha scale nil)
    dinput))

(defmethod $selu ((x node))
  (let ((alpha 1.6732632423543772848170429916717)
        (scale 1.0507009873554804934193349852946))
    (node ($selu ($data x))
          :name :selu
          :link (link (to x (dselu ($data x) dv gv alpha scale))))))

(defmethod $softmax ((x tensor))
  (let ((output ($clear x)))
    (nn-softmax-update-output x output)
    output))

(defun dsoftmax (input output gradient)
  (let ((dinput ($clear input)))
    (nn-softmax-update-grad-input input gradient dinput output)
    dinput))

(defmethod $softmax ((x node))
  (node ($softmax ($data x))
        :name :softmax
        :link (link (to x (dsoftmax ($data x) dv gv)))))

(defmethod $logsoftmax ((x tensor))
  (let ((output ($clear x)))
    (nn-log-softmax-update-output x output)
    output))

(defun dlogsoftmax (input output gradient)
  (let ((dinput ($clear input)))
    (nn-log-softmax-update-grad-input input gradient dinput output)
    dinput))

(defmethod $logsoftmax ((x node))
  (node ($logsoftmax ($data x))
        :name :logsoftmax
        :link (link (to x (dlogsoftmax ($data x) dv gv)))))

(defmethod $softplus ((x tensor))
  (let ((output ($clear x)))
    (nn-softplus-update-output x output 1 20)
    output))

(defun dsoftplus (input output gradient)
  (let ((dinput ($clear input)))
    (nn-softplus-update-grad-input input gradient dinput output 1 20)
    dinput))

(defmethod $softplus ((x node))
  (node ($softplus ($data x))
        :name :softplus
        :link (link (to x (dsoftplus ($data x) dv gv)))))

(defmethod $mish ((x number))
  (* x (tanh (log (+ 1 (exp x))))))

(defmethod $mish ((x tensor))
  ($* x ($tanh ($softplus x))))

(defmethod $mish ((x node))
  ($* x ($tanh ($softplus x))))

(defmethod $swish ((x number))
  (* x ($sigmoid x)))

(defmethod $swish ((x tensor))
  ($mul! ($sigmoid x) x))

(defun swish2 (x sx) ($mul sx x))

(defun dswish (x sx gv)
  ($mul! ($mul! ($add! ($mul! ($sub 1 sx) x) 1) sx) gv))

(defmethod $swish ((x node))
  (let ((sx ($sigmoid ($data x))))
    (node (swish2 ($data x) sx)
          :name :swish
          :link (link (to x (dswish ($data x) sx gv))))))

(defmethod $gelu ((x number)) (* 0.5 x (1+ (tanh (* (sqrt (/ 2 pi)) (+ x (* 0.044715 x x x)))))))
(defmethod $gelu ((x tensor))
  ($* 0.5 x ($+ 1 ($tanh ($* (sqrt (/ 2 pi)) ($+ x ($* 0.044715 x x x)))))))
(defmethod $gelu ((x node))
  ($* 0.5 x ($+ 1 ($tanh ($* (sqrt (/ 2 pi)) ($+ x ($* 0.044715 x x x)))))))

(defmethod $celu ((x number) &optional (α 1))
  (cond ((>= x 0) x)
        (* α (- (exp (/ x α)) 1))))

(defmethod $celu ((x tensor) &optional (α 1))
  (let ((output ($clear x)))
    (nn-celu-update-output x output α nil)
    output))

(defun dcelu (input output gradient &optional (alpha 1))
  (let ((dinput ($clear output)))
    (nn-celu-update-grad-input input gradient dinput output alpha nil)
    dinput))

(defmethod $celu ((x node) &optional (α 1))
  (node ($celu ($data x) α)
        :name :celu
        :link (link (to x (dcelu ($data x) dv gv α)))))
