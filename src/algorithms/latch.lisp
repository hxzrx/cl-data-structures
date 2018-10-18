(in-package #:cl-ds.alg)


(defclass latch-proxy (cl-ds:chunking-mixin
                       proxy-range)
  ((%latches :initarg :latches
             :accessor read-latches)))


(defclass forward-latch-proxy (latch-proxy
                               fundamental-forward-range)
  ())


(defmethod cl-ds:clone ((range latch-proxy))
  (make (type-of range)
        :original-range (cl-ds:clone (read-original-range range))
        :latches (map 'vector #'cl-ds:clone (read-latches range))))


(defmethod cl-ds:traverse (function (range latch-proxy))
  (let ((current (read-original-range range))
        (latches (read-latches range)))
    (iterate
      (for (values value more) = (cl-ds:consume-front current))
      (while more)
      (for go = t)
      (iterate
        (for latch in-vector latches)
        (for (values open more) = (cl-ds:consume-front latch))
        (unless more
          (return-from cl-ds:traverse range))
        (setf go (and go open))
        (finally (when go (funcall function value))))
      (finally (return range)))))


(defmethod cl-ds:across (function (range latch-proxy))
  (let ((current (read-original-range range))
        (latches (map 'vector #'cl-ds:clone (read-latches range))))
    (cl-ds:across (lambda (elt)
                    (let ((open (iterate
                                  (with result = t)
                                  (for latch in-vector latches)
                                  (for (values open more) =
                                       (cl-ds:consume-front latch))
                                  (unless more
                                    (return-from cl-ds:across range))
                                  (setf result (and open result))
                                  (finally (return result)))))
                      (when open
                        (funcall function elt))))
                  current)
    range))


(defmethod cl-ds:reset! ((range latch-proxy))
  (map nil #'cl-ds:reset! (access-latches range))
  (call-next-method)
  range)


(defun peek-or-consume (current latches)
  (iterate
    (for (values value more) = (cl-ds:consume-front current))
    (while more)
    (for r = t)
    (iterate
      (for latch in-vector latches)
      (for (values open more) = (cl-ds:consume-front latch))
      (unless more
        (return-from peek-or-consume (values nil nil)))
      (setf r (and open r))
      (finally (when r (return-from peek-or-consume (values value t)))))
    (finally (return (values nil nil)))))


(defmethod cl-ds:peek-front ((range forward-latch-proxy))
  (let ((current (cl-ds:clone (read-original-range range)))
        (latches (map 'vector #'cl-ds:clone (read-latches range))))
    (peek-or-consume current latches)))


(defmethod cl-ds:consume-front ((range forward-latch-proxy))
  (let ((current (read-original-range range))
        (latches (read-latches range)))
    (peek-or-consume current latches)))


(defclass latch-function (layer-function)
  ()
  (:metaclass closer-mop:funcallable-standard-class))


(defgeneric latch (range latch &rest more-latches)
  (:generic-function-class latch-function)
  (:method (range latch &rest more-latches)
    (apply-range-function range #'latch :latches (cons latch more-latches))))


(defmethod apply-layer ((range fundamental-forward-range)
                        (function latch-function)
                        &rest all &key latches)
  (declare (ignore all))
  (make 'forward-latch-proxy
        :original-range range
        :latches (coerce latches 'vector)))
