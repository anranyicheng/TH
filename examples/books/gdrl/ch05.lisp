(defpackage :gdrl-ch05
  (:use #:common-lisp
        #:mu
        #:mplot
        #:th
        #:th.env)
  (:import-from #:th.env.examples))

(in-package :gdrl-ch05)

(let* ((env (th.env.examples:random-walk-env))
       (goal 6)
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s)))
       (v-true (env/policy-evaluation env policy)))
  (env/print-state-value-function env v-true :ncols 7)
  (env/print-policy env policy :action-symbols '("<" ">") :ncols 7)
  (prn "PGOAL:" (env/success-probability env policy goal)
       "MRET:" (env/mean-return env policy)))

(defun generate-trajectory (env policy &key (max-steps 200))
  (let ((done nil)
        (trajectory '()))
    (loop :while (not done)
          :for state = (env/reset! env)
          :do (loop :for e :from 0 :to max-steps
                    :while (not done)
                    :do (let* ((action (funcall policy state))
                               (tx (env/step! env action))
                               (next-state (transition/next-state tx))
                               (reward (transition/reward tx))
                               (terminalp (transition/terminalp tx)))
                          (push (list state action reward next-state terminalp)
                                trajectory)
                          (setf done terminalp
                                state next-state)
                          (when (>= e max-steps)
                            (setf trajectory '())))))
    (reverse trajectory)))

(defun experience/state (record) ($ record 0))
(defun experience/action (record) ($ record 1))
(defun experience/reward (record) ($ record 2))
(defun experience/next-state (record) ($ record 3))
(defun experience/terminalp (record) ($ record 4))

(defun decay-schedule (v0 minv decay-ratio max-steps &key (log-start -2) (log-base 10))
  (let* ((decay-steps (round (* max-steps decay-ratio)))
         (rem-steps (- max-steps decay-steps))
         (vs (-> ($/ (logspace log-start 0 decay-steps) (log log-base 10))
                 ($list)
                 (reverse)
                 (tensor)))
         (vs ($/ ($- vs ($min vs)) ($- ($max vs) ($min vs))))
         (vs ($+ minv ($* vs (- v0 minv)))))
    ($cat vs ($fill! (tensor rem-steps) ($last vs)))))

(defun mc-prediction (env policy &key (gamma 1D0) (alpha0 0.5) (min-alpha 0.01)
                                   (alpha-decay-ratio 0.5) (nepisodes 500) (max-steps 200)
                                   (first-visit-p T))
  (let* ((alphas (decay-schedule alpha0 min-alpha alpha-decay-ratio nepisodes))
         (ns (env/state-count env))
         (v (zeros ns))
         (v-track (zeros nepisodes ns))
         (targets (loop :for s :from 0 :below ns :collect '())))
    (loop :for e :from 0 :below nepisodes
          :for trajectory = (generate-trajectory env policy :max-steps max-steps)
          :for visited = (zeros ns)
          :do (progn
                (loop :for strj :on trajectory
                      :for experience = (car strj)
                      :for state = (experience/state experience)
                      :for it :from 0
                      :do (unless (and first-visit-p (> ($ visited state) 0))
                            (let* ((strj (subseq trajectory it))
                                   (g (loop :for exi :in strj
                                            :for ri = (experience/reward exi)
                                            :for i :from 0
                                            :summing (* (expt gamma i) ri)))
                                   (mc-err (- g ($ v state))))
                              (setf ($ visited state) 1)
                              (push g ($ targets state))
                              (incf ($ v state) (* ($ alphas e) mc-err)))))
                (setf ($ v-track e) v)))
    (list v v-track targets)))

(defun prediction/state-value-function (record) ($ record 0))
(defun prediction/state-value-function-trakc (record) ($ record 1))
(defun prediction/targets (record) ($ record 2))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s))))
  (env/print-policy env policy :ncols 7)
  (generate-trajectory env policy))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s))))
  (mc-prediction env policy))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s)))
       (v-true (env/policy-evaluation env policy))
       (mcpred (mc-prediction env policy))
       (v (prediction/state-value-function mcpred)))
  (env/print-state-value-function env v :ncols 7)
  (env/print-state-value-function env v-true :ncols 7 :title "TRUE")
  (env/print-state-value-function env ($- v v-true) :ncols 7 :title "ERROR"))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s)))
       (v-true (env/policy-evaluation env policy))
       (mcpred (mc-prediction env policy :first-visit-p nil))
       (v (prediction/state-value-function mcpred)))
  (env/print-state-value-function env v :ncols 7)
  (env/print-state-value-function env v-true :ncols 7 :title "TRUE")
  (env/print-state-value-function env ($- v v-true) :ncols 7 :title "ERROR"))

(defun td-prediction (env policy &key (gamma 1D0) (alpha0 0.5) (min-alpha 0.01)
                                   (alpha-decay-ratio 0.5) (nepisodes 500))
  (let* ((alphas (decay-schedule alpha0 min-alpha alpha-decay-ratio nepisodes))
         (ns (env/state-count env))
         (v (zeros ns))
         (v-track (zeros nepisodes ns))
         (targets (loop :for s :from 0 :below ns :collect '())))
    (loop :for e :from 0 :below nepisodes
          :for state = (env/reset! env)
          :for done = nil
          :do (progn
                (loop :while (not done)
                      :for action = (funcall policy state)
                      :for tx = (env/step! env action)
                      :for next-state = (transition/next-state tx)
                      :for reward = (transition/reward tx)
                      :for terminalp = (transition/terminalp tx)
                      :for td-target = (+ reward (* gamma ($ v next-state) (if terminalp 0 1)))
                      :do (progn
                            (push td-target ($ targets state))
                            (incf ($ v state) (* ($ alphas e) (- td-target ($ v state))))
                            (setf done terminalp
                                  state next-state)))
                (setf ($ v-track e) v)))
    (list v v-track targets)))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s))))
  (td-prediction env policy))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s)))
       (v-true (env/policy-evaluation env policy))
       (mcpred (td-prediction env policy))
       (v (prediction/state-value-function mcpred)))
  (env/print-state-value-function env v :ncols 7)
  (env/print-state-value-function env v-true :ncols 7 :title "TRUE")
  (env/print-state-value-function env ($- v v-true) :ncols 7 :title "ERROR"))

;; from sutton & barto's book
(defun ntd-prediction (env policy &key (gamma 1D0) (alpha0 0.5) (min-alpha 0.01)
                                    (alpha-decay-ratio 0.5) (nstep 3) (nepisodes 500))
  (let* ((alphas (decay-schedule alpha0 min-alpha alpha-decay-ratio nepisodes))
         (ns (env/state-count env))
         (v (zeros ns))
         (v-track (zeros nepisodes ns)))
    (loop :for e :from 0 :below nepisodes
          :for state = (env/reset! env)
          :for ende = most-positive-fixnum
          :for endp = nil
          :do (let ((rewards '())
                    (states (list state)) ;; XXX states is required to refer S(tau)
                    (next-state -1)
                    (tau -1))
                (loop :for tm :from 0
                      :while (not endp)
                      :do (progn
                            (when (< tm ende)
                              (let* ((action (funcall policy state))
                                     (tx (env/step! env action)))
                                (setf next-state (transition/next-state tx))
                                (push next-state states)
                                (push (transition/reward tx) rewards)
                                (if (transition/terminalp tx) (setf ende (1+ tm)))))
                            (setf tau (+ 1 (- tm nstep)))
                            (when (>= tau 0)
                              (let* ((rs (subseq (reverse rewards)
                                                 (1+ tau) (min ende (+ tau nstep))))
                                     (sts (reverse states))
                                     (stau ($ sts tau))
                                     (g (loop :for r :in rs
                                              :for i :from 0
                                              :summing (* (expt gamma (- i tau 1)) r))))
                                (when (< (+ tau nstep) ende)
                                  (incf g (* (expt gamma nstep) ($ v next-state))))
                                (incf ($ v stau) (* ($ alphas e) (- g ($ v stau))))))
                            (if (= tau (- ende 1)) (setf endp T))
                            (setf state next-state)))
                (setf ($ v-track e) v)))
    (list v v-track '())))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s))))
  (ntd-prediction env policy :nstep 100))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s)))
       (v-true (env/policy-evaluation env policy))
       (ntdpred (ntd-prediction env policy))
       (v (prediction/state-value-function ntdpred)))
  (env/print-state-value-function env v :ncols 7)
  (env/print-state-value-function env v-true :ncols 7 :title "TRUE")
  (env/print-state-value-function env ($- v v-true) :ncols 7 :title "ERROR"))

(defun ntd-prediction (env policy &key (gamma 1D0) (alpha0 0.5) (min-alpha 0.01)
                                    (alpha-decay-ratio 0.5) (nstep 3) (nepisodes 500))
  (let* ((alphas (decay-schedule alpha0 min-alpha alpha-decay-ratio nepisodes))
         (ns (env/state-count env))
         (v (zeros ns))
         (v-track (zeros nepisodes ns)))
    (loop :for e :from 0 :below nepisodes
          :for state = (env/reset! env)
          :for done = nil
          :do (let ((experiences '()))
                (loop :while (or (not done) (not (null experiences)))
                      :do (progn
                            (loop :while (and (not done) (< ($count experiences) nstep))
                                  :for action = (funcall policy state)
                                  :for tx = (env/step! env action)
                                  :for next-state = (transition/next-state tx)
                                  :for reward = (transition/reward tx)
                                  :for terminalp = (transition/terminalp tx)
                                  :for experience = (list state action reward next-state terminalp)
                                  :do (progn
                                        (push experience experiences)
                                        (setf state next-state)
                                        (setf done terminalp)))
                            (when experiences
                              (let* ((ne ($count experiences))
                                     (exs (reverse experiences))
                                     (e0 (car exs))
                                     (el ($last exs))
                                     (est-state (experience/state e0))
                                     (next-state (experience/next-state el))
                                     (termp (experience/terminalp el))
                                     (partial-returns (loop :for exp :in exs
                                                            :for n :from 0
                                                            :for reward = (experience/reward exp)
                                                            :summing (* (expt gamma n) reward)))
                                     (bs-val (* (expt gamma nstep) ($ v next-state)
                                                (if termp 0 1)))
                                     (ntd-target (+ bs-val partial-returns))
                                     (ntd-error (- ntd-target ($ v est-state))))
                                (incf ($ v est-state) (* ($ alphas e) ntd-error))
                                (when (and (= 1 ne) (experience/terminalp e0))
                                  (setf experiences '()))))
                            (setf experiences (butlast experiences))))
                (setf ($ v-track e) v)))
    (list v v-track '())))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s))))
  (ntd-prediction env policy))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s)))
       (v-true (env/policy-evaluation env policy))
       (ntdpred (ntd-prediction env policy))
       (v (prediction/state-value-function ntdpred)))
  (env/print-state-value-function env v :ncols 7)
  (env/print-state-value-function env v-true :ncols 7 :title "TRUE")
  (env/print-state-value-function env ($- v v-true) :ncols 7 :title "ERROR"))

(defun td-lambda (env policy &key (gamma 1D0) (alpha0 0.5) (min-alpha 0.01)
                               (alpha-decay-ratio 0.5) (lam 0.3) (nepisodes 500))
  (let* ((alphas (decay-schedule alpha0 min-alpha alpha-decay-ratio nepisodes))
         (ns (env/state-count env))
         (v (zeros ns))
         (es (zeros ns))
         (v-track (zeros nepisodes ns)))
    (loop :for e :from 0 :below nepisodes
          :for state = (env/reset! env)
          :for done = nil
          :do (progn
                ($zero! es)
                (loop :while (not done)
                      :for action = (funcall policy state)
                      :for tx = (env/step! env action)
                      :for next-state = (transition/next-state tx)
                      :for reward = (transition/reward tx)
                      :for terminalp = (transition/terminalp tx)
                      :for fac = (if terminalp 0 1)
                      :for td-target = (+ reward (* gamma ($ v next-state) fac))
                      :for td-error = (- td-target ($ v state))
                      :for alpha-err = (* ($ alphas e) td-error)
                      :do (progn
                            (incf ($ es state))
                            ($add! v ($* alpha-err es))
                            (setf es ($* es gamma lam))
                            (setf done terminalp
                                  state next-state)))
                (setf ($ v-track e) v)))
    (list v v-track '())))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s))))
  (td-lambda env policy))

(let* ((env (th.env.examples:random-walk-env))
       (policy (lambda (s) ($ '(0 0 0 0 0 0 0) s)))
       (v-true (env/policy-evaluation env policy))
       (ntlpred (td-lambda env policy))
       (v (prediction/state-value-function ntlpred)))
  (env/print-state-value-function env v :ncols 7)
  (env/print-state-value-function env v-true :ncols 7 :title "TRUE")
  (env/print-state-value-function env ($- v v-true) :ncols 7 :title "ERROR"))

(let* ((env (th.env.examples:grid-world-env))
       (policy (lambda (s) ($ '(2 2 2 0
                           3 0 3 0
                           3 0 0 0)
                        s)))
       (v-true (env/policy-evaluation env policy)))
  (env/print-state-value-function env v-true)
  (td-lambda env policy))

(let* ((env (th.env.examples:grid-world-env))
       (policy (lambda (s) ($ '(2 2 2 0
                           3 0 3 0
                           3 0 0 0)
                        s)))
       (v-true (env/policy-evaluation env policy))
       (pred (mc-prediction env policy))
       (v (prediction/state-value-function pred)))
  (env/print-policy env policy)
  (env/print-state-value-function env v)
  (env/print-state-value-function env v-true :title "TRUE")
  (env/print-state-value-function env ($- v v-true) :title "ERROR"))

(let* ((env (th.env.examples:grid-world-env))
       (policy (lambda (s) ($ '(2 2 2 0
                           3 0 3 0
                           3 0 0 0)
                        s)))
       (v-true (env/policy-evaluation env policy))
       (pred (td-lambda env policy))
       (v (prediction/state-value-function pred)))
  (env/print-policy env policy)
  (env/print-state-value-function env v)
  (env/print-state-value-function env v-true :title "TRUE")
  (env/print-state-value-function env ($- v v-true) :title "ERROR")
  (prn "PGOAL:" (env/success-probability env policy 3)
       "MRET:" (env/mean-return env policy)))
