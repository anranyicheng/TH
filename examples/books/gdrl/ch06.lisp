(defpackage :gdrl-ch06
  (:use #:common-lisp
        #:mu
        #:th
        #:th.env)
  (:import-from #:th.env.examples))

(in-package :gdrl-ch06)

(defun decay-schedule (v0 minv decay-ratio max-steps &key (log-start -2) (log-base 10))
  (let* ((decay-steps (round (* max-steps decay-ratio)))
         (rem-steps (- max-steps decay-steps))
         (vs (-> ($/ (logspace log-start 0 decay-steps) (log log-base 10))
                 ($list)
                 (reverse)
                 (tensor)))
         (minvs ($min vs))
         (maxvs ($max vs))
         (rngv (- maxvs minvs))
         (vs ($/ ($- vs minvs) rngv))
         (vs ($+ minv ($* vs (- v0 minv)))))
    ($cat vs ($fill! (tensor rem-steps) ($last vs)))))

(defun discounts (gamma max-steps)
  (loop :for i :from 0 :below max-steps :collect (expt gamma i)))

(defun generate-trajectory (env Q select-action epsilon &key (max-steps 200))
  (let ((done nil)
        (trajectory '()))
    (loop :while (not done)
          :for state = (env/reset! env)
          :do (loop :for e :from 0 :to max-steps
                    :while (not done)
                    :do (let* ((action (funcall select-action Q state epsilon))
                               (tx (env/step! env action))
                               (next-state (transition/next-state tx))
                               (reward (transition/reward tx))
                               (terminalp (transition/terminalp tx))
                               (experience (list state action reward next-state terminalp)))
                          (push experience trajectory)
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

(defun mc-control (env &key (gamma 1D0)
                         (alpha0 0.5) (min-alpha 0.01) (alpha-decay-ratio 0.5)
                         (epsilon0 1.0) (min-epsilon 0.1) (epsilon-decay-ratio 0.9)
                         (nepisodes 3000)
                         (max-steps 200)
                         (first-visit-p T))
  (let* ((ns (env/state-count env))
         (na (env/action-count env))
         (discounts (discounts gamma max-steps))
         (alphas (decay-schedule alpha0 min-alpha alpha-decay-ratio nepisodes))
         (epsilons (decay-schedule epsilon0 min-epsilon epsilon-decay-ratio nepisodes))
         (pi-track '())
         (Q (zeros ns na))
         (Q-track (zeros nepisodes ns na))
         (select-action (lambda (Q state epsilon)
                          (if (> (random 1D0) epsilon)
                              ($argmax ($ Q state))
                              (random ($count ($ Q state)))))))
    (loop :for e :from 0 :below nepisodes
          :for eps = ($ epsilons e)
          :for trajectory = (generate-trajectory env Q select-action eps :max-steps max-steps)
          :for visited = (zeros ns na)
          :do (progn
                (loop :for strj :on trajectory
                      :for experience = (car strj)
                      :for state = (experience/state experience)
                      :for action = (experience/action experience)
                      :for reward = (experience/reward experience)
                      :do (unless (and first-visit-p (> ($ visited state action) 0))
                            (let* ((g (->> (mapcar (lambda (d e) (* d (experience/reward e)))
                                                   discounts strj)
                                           (reduce #'+)))
                                   (mc-err (- g ($ Q state action))))
                              (setf ($ visited state action) 1)
                              (incf ($ Q state action) (* ($ alphas e) mc-err)))))
                (setf ($ Q-track e) Q)
                (push ($squeeze ($argmax Q 1)) pi-track)))
    (let ((v ($squeeze (car ($max Q 1))))
          (va ($squeeze ($argmax Q 1))))
      (list Q v (lambda (s) ($ va s)) Q-track (reverse pi-track)))))

(let* ((env (th.env.examples:slippery-walk-seven-env))
       (optres (env/value-iteration env :gamma 0.99D0))
       (opt-v (value-iteration/optimal-value-function optres))
       (opt-p (value-iteration/optimal-policy optres))
       (opt-q (value-iteration/optimal-action-value-function optres)))
  (env/print-state-value-function env opt-v :ncols 9)
  (env/print-policy env opt-p :action-symbols '("<" ">") :ncols 9)
  (prn opt-q))

(let* ((env (th.env.examples:slippery-walk-seven-env))
       (res (mc-control env :gamma 0.99D0 :nepisodes 3000))
       (Q ($ res 0))
       (v ($ res 1))
       (policy ($ res 2)))
  (env/print-state-value-function env v :ncols 9)
  (env/print-policy env policy :action-symbols '("<" ">") :ncols 9)
  (prn Q))

(let* ((env (th.env.examples:slippery-walk-seven-env))
       (res (mc-control env :gamma 0.99D0 :nepisodes 3000 :first-visit-p nil))
       (Q ($ res 0))
       (v ($ res 1))
       (policy ($ res 2)))
  (env/print-state-value-function env v :ncols 9)
  (env/print-policy env policy :action-symbols '("<" ">") :ncols 9)
  (prn Q))

(defun sarsa (env &key (gamma 1D0)
                    (alpha0 0.5) (min-alpha 0.01) (alpha-decay-ratio 0.5)
                    (epsilon0 1.0) (min-epsilon 0.1) (epsilon-decay-ratio 0.9)
                    (nepisodes 3000))
  (let* ((ns (env/state-count env))
         (na (env/action-count env))
         (pi-track '())
         (Q (zeros ns na))
         (Q-track (zeros nepisodes ns na))
         (alphas (decay-schedule alpha0 min-alpha alpha-decay-ratio nepisodes))
         (epsilons (decay-schedule epsilon0 min-epsilon epsilon-decay-ratio nepisodes))
         (select-action (lambda (Q state epsilon)
                          (if (> (random 1D0) epsilon)
                              ($argmax ($ Q state))
                              (random ($count ($ Q state)))))))
    (loop :for e :from 0 :below nepisodes
          :for state = (env/reset! env)
          :for eps = ($ epsilons e)
          :for action = (funcall select-action Q state eps)
          :do (let ((done nil))
                (loop :while (not done)
                      :do (let* ((tx (env/step! env action))
                                 (next-state (transition/next-state tx))
                                 (reward (transition/reward tx))
                                 (terminalp (transition/terminalp tx))
                                 (next-action (funcall select-action Q next-state eps))
                                 (td-target (+ reward (* gamma ($ Q next-state next-action)
                                                         (if terminalp 0 1))))
                                 (td-error (- td-target ($ Q state action))))
                            (incf ($ Q state action) (* ($ alphas e) td-error))
                            (setf done terminalp
                                  state next-state
                                  action next-action)))
                (setf ($ Q-track e) Q)
                (push ($squeeze ($argmax Q 1)) pi-track)))
    (let ((v ($squeeze (car ($max Q 1))))
          (va ($squeeze ($argmax Q 1))))
      (list Q v (lambda (s) ($ va s)) Q-track (reverse pi-track)))))

(let* ((env (th.env.examples:slippery-walk-seven-env))
       (optres (env/value-iteration env :gamma 0.99D0))
       (opt-v (value-iteration/optimal-value-function optres))
       (opt-p (value-iteration/optimal-policy optres))
       (opt-q (value-iteration/optimal-action-value-function optres)))
  (env/print-state-value-function env opt-v :ncols 9)
  (env/print-policy env opt-p :action-symbols '("<" ">") :ncols 9)
  (prn opt-q))

(let* ((env (th.env.examples:slippery-walk-seven-env))
       (res (sarsa env :gamma 0.99D0 :nepisodes 3000))
       (Q ($ res 0))
       (v ($ res 1))
       (policy ($ res 2)))
  (env/print-state-value-function env v :ncols 9)
  (env/print-policy env policy :action-symbols '("<" ">") :ncols 9)
  (prn Q))

(defun q-learning (env &key (gamma 1D0)
                         (alpha0 0.5) (min-alpha 0.01) (alpha-decay-ratio 0.5)
                         (epsilon0 1.0) (min-epsilon 0.1) (epsilon-decay-ratio 0.9)
                         (nepisodes 3000))
  (let* ((ns (env/state-count env))
         (na (env/action-count env))
         (pi-track '())
         (Q (zeros ns na))
         (Q-track (zeros nepisodes ns na))
         (alphas (decay-schedule alpha0 min-alpha alpha-decay-ratio nepisodes))
         (epsilons (decay-schedule epsilon0 min-epsilon epsilon-decay-ratio nepisodes))
         (select-action (lambda (Q state epsilon)
                          (if (> (random 1D0) epsilon)
                              ($argmax ($ Q state))
                              (random ($count ($ Q state)))))))
    (loop :for e :from 0 :below nepisodes
          :for state = (env/reset! env)
          :for eps = ($ epsilons e)
          :do (let ((done nil))
                (loop :while (not done)
                      :do (let* ((action (funcall select-action Q state eps))
                                 (tx (env/step! env action))
                                 (next-state (transition/next-state tx))
                                 (reward (transition/reward tx))
                                 (terminalp (transition/terminalp tx))
                                 (td-target (+ reward (* gamma ($max ($ Q next-state))
                                                         (if terminalp 0 1))))
                                 (td-error (- td-target ($ Q state action))))
                            (incf ($ Q state action) (* ($ alphas e) td-error))
                            (setf done terminalp
                                  state next-state)))
                (setf ($ Q-track e) Q)
                (push ($squeeze ($argmax Q 1)) pi-track)))
    (let ((v ($squeeze (car ($max Q 1))))
          (va ($squeeze ($argmax Q 1))))
      (list Q v (lambda (s) ($ va s)) Q-track (reverse pi-track)))))

(let* ((env (th.env.examples:slippery-walk-seven-env))
       (optres (env/value-iteration env :gamma 0.99D0))
       (opt-v (value-iteration/optimal-value-function optres))
       (opt-p (value-iteration/optimal-policy optres))
       (opt-q (value-iteration/optimal-action-value-function optres)))
  (env/print-state-value-function env opt-v :ncols 9)
  (env/print-policy env opt-p :action-symbols '("<" ">") :ncols 9)
  (prn opt-q))

(let* ((env (th.env.examples:slippery-walk-seven-env))
       (res (q-learning env :gamma 0.99D0 :nepisodes 3000))
       (Q ($ res 0))
       (v ($ res 1))
       (policy ($ res 2)))
  (env/print-state-value-function env v :ncols 9)
  (env/print-policy env policy :action-symbols '("<" ">") :ncols 9)
  (prn Q))

(defun double-q-learning (env &key (gamma 1D0)
                                (alpha0 0.5) (min-alpha 0.01) (alpha-decay-ratio 0.5)
                                (epsilon0 1.0) (min-epsilon 0.1) (epsilon-decay-ratio 0.9)
                                (nepisodes 3000))
  (let* ((ns (env/state-count env))
         (na (env/action-count env))
         (pi-track '())
         (Q1 (zeros ns na))
         (Q2 (zeros ns na))
         (Q1-track (zeros nepisodes ns na))
         (Q2-track (zeros nepisodes ns na))
         (alphas (decay-schedule alpha0 min-alpha alpha-decay-ratio nepisodes))
         (epsilons (decay-schedule epsilon0 min-epsilon epsilon-decay-ratio nepisodes))
         (select-action (lambda (Q state epsilon)
                          (if (> (random 1D0) epsilon)
                              ($argmax ($ Q state))
                              (random ($count ($ Q state)))))))
    (loop :for e :from 0 :below nepisodes
          :for state = (env/reset! env)
          :for eps = ($ epsilons e)
          :do (let ((done nil))
                (loop :while (not done)
                      :do (let* ((action (funcall select-action ($/ ($+ Q1 Q2) 2) state eps))
                                 (tx (env/step! env action))
                                 (next-state (transition/next-state tx))
                                 (reward (transition/reward tx))
                                 (terminalp (transition/terminalp tx))
                                 (fac (if terminalp 0 1)))
                            (if (zerop (random 2))
                                (let* ((argmaxQ1 ($argmax ($ Q1 next-state)))
                                       (td-target (+ reward
                                                     (* gamma
                                                        ($ Q2 next-state argmaxQ1)
                                                        fac)))
                                       (td-error (- td-target ($ Q1 state action))))
                                  (incf ($ Q1 state action) (* ($ alphas e) td-error)))
                                (let* ((argmaxQ2 ($argmax ($ Q2 next-state)))
                                       (td-target (+ reward
                                                     (* gamma
                                                        ($ Q1 next-state argmaxQ2)
                                                        fac)))
                                       (td-error (- td-target ($ Q2 state action))))
                                  (incf ($ Q2 state action) (* ($ alphas e) td-error))))
                            (setf done terminalp
                                  state next-state)))
                (setf ($ Q1-track e) Q1)
                (setf ($ Q2-track e) Q2)
                (push ($squeeze ($argmax ($/ ($+ Q1 Q2) 2) 1)) pi-track)))
    (let* ((Q ($/ ($+ Q1 Q2) 2))
           (v ($squeeze (car ($max Q 1))))
           (va ($squeeze ($argmax Q 1))))
      (list Q v (lambda (s) ($ va s)) ($/ ($+ Q1-track Q2-track) 2) (reverse pi-track)))))

(let* ((env (th.env.examples:slippery-walk-seven-env))
       (optres (env/value-iteration env :gamma 0.99D0))
       (opt-v (value-iteration/optimal-value-function optres))
       (opt-p (value-iteration/optimal-policy optres))
       (opt-q (value-iteration/optimal-action-value-function optres)))
  (env/print-state-value-function env opt-v :ncols 9)
  (env/print-policy env opt-p :action-symbols '("<" ">") :ncols 9)
  (prn opt-q))

(let* ((env (th.env.examples:slippery-walk-seven-env))
       (res (double-q-learning env :gamma 0.99D0 :nepisodes 3000))
       (Q ($ res 0))
       (v ($ res 1))
       (policy ($ res 2)))
  (env/print-state-value-function env v :ncols 9)
  (env/print-policy env policy :action-symbols '("<" ">") :ncols 9)
  (prn Q))

(let* ((env (th.env.examples:grid-world-env))
       (policy (lambda (s) ($ '(2 2 2 0
                           3 0 3 0
                           3 0 0 0)
                        s)))
       (v-true (env/policy-evaluation env policy)))
  (env/print-state-value-function env v-true))

(let* ((env (th.env.examples:grid-world-env))
       (optres (env/value-iteration env))
       (opt-v (value-iteration/optimal-value-function optres))
       (opt-p (value-iteration/optimal-policy optres))
       (opt-q (value-iteration/optimal-action-value-function optres)))
  (env/print-state-value-function env opt-v)
  (env/print-policy env opt-p :action-symbols '("<" "v" ">" "^"))
  (prn opt-q))

(let* ((env (th.env.examples:grid-world-env))
       (res (mc-control env :nepisodes 4000))
       (Q ($ res 0))
       (v ($ res 1))
       (policy ($ res 2)))
  (env/print-state-value-function env v)
  (env/print-policy env policy :action-symbols '("<" "v" ">" "^"))
  (prn Q))

(let* ((env (th.env.examples:grid-world-env))
       (res (sarsa env :nepisodes 4000))
       (Q ($ res 0))
       (v ($ res 1))
       (policy ($ res 2)))
  (env/print-state-value-function env v)
  (env/print-policy env policy :action-symbols '("<" "v" ">" "^"))
  (prn Q))

(let* ((env (th.env.examples:grid-world-env))
       (res (q-learning env :nepisodes 4000))
       (Q ($ res 0))
       (v ($ res 1))
       (policy ($ res 2)))
  (env/print-state-value-function env v)
  (env/print-policy env policy :action-symbols '("<" "v" ">" "^"))
  (prn Q))

(let* ((env (th.env.examples:grid-world-env))
       (res (double-q-learning env :nepisodes 4000))
       (Q ($ res 0))
       (v ($ res 1))
       (policy ($ res 2)))
  (env/print-state-value-function env v)
  (env/print-policy env policy :action-symbols '("<" "v" ">" "^"))
  (prn Q))
