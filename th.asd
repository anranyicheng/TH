(defsystem th
  :name "th"
  :author "Sungjin Chun <chunsj@gmail.com>"
  :version "1.2"
  :maintainer "Sungjin Chun <chunsj@gmail.com>"
  :license "GPL3"
  :description "common lisp tensor and deep learning library"
  :long-description "common lisp tensor and deep learning library built on TH and THNN from torch"
  :depends-on ("cffi"
               "mu")
  :components ((:file "package")
               (:module ffi :components ((:file "macros")
                                         (:file "libs")
                                         (:file "structs")
                                         (:file "mhack")
                                         (:file "generator")
                                         (:file "storages")
                                         (:file "tensors")))
               (:module object :components ((:file "object")
                                            (:file "generator")
                                            (:file "storage")
                                            (:file "tensor")
                                            (:file "file")))
               (:module private :components ((:file "interface")
                                             (:file "implementation")))
               (:module binding :components ((:file "th")
                                             (:file "generator")
                                             (:file "storage")
                                             (:file "tensor")
                                             (:file "file")))
               (:module nn :components ((:file "ffi")
                                        (:file "nn")))
               (:module ad :components ((:file "autograd")
                                        (:file "gd")
                                        (:file "operator")
                                        (:file "function")
                                        (:file "support")
                                        (:file "conv")
                                        (:file "utility")))
               (:module m :components ((:file "imagenet")
                                       (:file "vgg16")
                                       (:file "vgg19")
                                       (:file "resnet50")
                                       (:file "densenet161")
                                       (:file "squeezenet11")))))
