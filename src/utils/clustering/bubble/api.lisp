(cl:in-package #:cl-data-structures.utils.clustering.bubble)


(defun make-bubble-fn (tree)
  (lambda (leaf)
    (make 'bubble
          :content (leaf-content tree leaf)
          :clusteroid (clusteroid tree leaf))))


(defun bubble-grouping (data
                        distance-function
                        sampling-rate
                        sample-size
                        subtree-maximum-arity
                        leaf-maximum-size
                        leaf-maximum-radius
                        &key
                          (parallel nil)
                          (parallel-sample-size 100)
                          (parallel-samples-count 500))
  (let ((tree (make 'cf-tree :distance-function distance-function
                             :sampling-rate sampling-rate
                             :subtree-maximum-arity subtree-maximum-arity
                             :leaf-maximum-size leaf-maximum-size
                             :leaf-maximum-radius leaf-maximum-radius
                             :subtree-sample-size sample-size
                             :parallel-sample-size parallel-sample-size
                             :parallel-samples-count parallel-samples-count)))
    (~> (if parallel
            (parallel-bubble-grouping tree data)
            (single-thread-bubble-grouping tree data))
        (gather-leafs tree _ :key (make-bubble-fn tree)))))


(defun bubble-clusteroid (bubble)
  (check-type bubble bubble)
  (read-clusteroid bubble))


(defun bubble-content (bubble)
  (check-type bubble bubble)
  (read-content bubble))
