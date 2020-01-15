(cl:in-package #:cl-data-structures.math)


(defun fast-map-embeddings (data metric-function dimensions iterations parallel)
  (bind ((length (length data))
         (distance-matrix (if parallel
                              (cl-ds.utils:parallel-make-distance-matrix-from-vector
                               'single-float
                               #1=(lambda (a b)
                                    (coerce (funcall metric-function a b)
                                            'single-float))
                               data)
                              (cl-ds.utils:make-distance-matrix-from-vector 'single-float #1# data)))
         (result (make-array `(,length ,dimensions)
                             :element-type 'single-float
                             :initial-element 0.0f0))
         ((:labels distance (a b axis))
          (if (zerop axis)
              (if (= a b)
                  0.0f0
                  (cl-ds.utils:mref distance-matrix a b))
              (~> (distance a b (1- axis))
                  (expt 2)
                  (- (expt (- (aref result a (1- axis))
                              (aref result b (1- axis)))
                           2))
                  sqrt)))
         ((:flet furthest (o axis))
          (iterate
            (for i from 0 below length)
            (finding i maximizing (distance i o axis))))
         ((:flet select-pivots (axis))
          (iterate
            (with o1 = (random length))
            (with o2 = -1)
            (with o = -1)
            (repeat iterations)
            (setf o (furthest o1 axis))
            (when (= o o2) (finish))
            (shiftf o2 o (furthest o axis))
            (when (= o o1) (finish))
            (setf o1 o)
            (finally
             (return (cons o1 o2)))))
         ((:flet project (i x y axis dxy))
          (bind ((dix (expt (distance i x axis) 2))
                 (diy (expt (distance i y axis) 2)))
            (/ (+ dix dxy (- diy))
               (* 2 dxy))))
         ((:labels impl (axis))
          (when (= axis dimensions)
            (return-from impl nil))
          (bind (((first-distant . second-distant) (select-pivots axis))
                 (distance (distance first-distant second-distant axis)))
            (iterate
              (for i from 0 below length)
              (setf (aref result i axis)
                    (cond ((= i first-distant) 0.0f0)
                          ((= i second-distant) distance)
                          (t (project i first-distant
                                      second-distant axis distance))))
              (finally (impl (1+ axis)))))))
    (impl 0)
    result))


(cl-ds.alg.meta:define-aggregation-function
    fast-map fast-map-function

    (:range metric-function dimensions iterations &key key parallel)
    (:range metric-function dimensions iterations &key (key #'identity) parallel)

    (%data %distance-function %dimensions %iterations %parallel)

    ((&key metric-function dimensions iterations parallel &allow-other-keys)
     (setf %data (vect)
           %distance-function metric-function
           %parallel parallel
           %iterations iterations
           %dimensions dimensions))

    ((element)
     (vector-push-extend element %data))

    ((fast-map-embeddings %data %distance-function %dimensions %iterations %parallel)))
