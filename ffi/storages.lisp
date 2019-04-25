(declaim (optimize (speed 3) (debug 1) (safety 0)))

(in-package :th)

(defparameter *th-storage-functions*
  '(("data" data realptr (storage storageptr))
    ("size" size ptrdiff-t (storage storageptr))
    ("elementSize" element-size size-t)
    ("set" set :void (storage storageptr) (loc ptrdiff-t) (value real))
    ("get" get real (storage storageptr) (loc ptrdiff-t))
    ("new" new storageptr)
    ("newWithSize" new-with-size storageptr (size ptrdiff-t))
    ("newWithSize1" new-with-size1 storageptr (size real))
    ("newWithSize2" new-with-size2 storageptr (size1 real) (size2 real))
    ("newWithSize3" new-with-size3 storageptr (size1 real) (size2 real) (size3 real))
    ("newWithSize4" new-with-size4 storageptr (size1 real) (size2 real) (size3 real) (size4 real))
    ("newWithMapping" new-with-mapping storageptr (filename :string) (size ptrdiff-t) (flags :int))
    ("newWithData" new-with-data storageptr (data realptr) (size ptrdiff-t))
    ("setFlag" set-flag :void (storage storageptr) (flag :char))
    ("clearFlag" clear-flag :void (storage storageptr) (flag :char))
    ("retain" retain :void (storage storageptr))
    ("swap" swap :void (storage1 storageptr) (storage2 storageptr))
    ("free" free :void (storage storageptr))
    ("resize" resize :void (storage storageptr) (size ptrdiff-t))
    ("fill" fill :void (storage storageptr) (value real))
    ("rawCopy" raw-copy :void (storage storageptr) (src realptr))
    ("copy" copy :void (storage storageptr) (src storageptr))
    ("copyByte" copy-byte :void (storage storageptr) (src th-byte-storage-ptr))
    ("copyChar" copy-char :void (storage storageptr) (src th-char-storage-ptr))
    ("copyShort" copy-short :void (storage storageptr) (src th-short-storage-ptr))
    ("copyInt" copy-int :void (storage storageptr) (src th-int-storage-ptr))
    ("copyLong" copy-long :void (storage storageptr) (src th-long-storage-ptr))
    ("copyFloat" copy-float :void (storage storageptr) (src th-float-storage-ptr))
    ("copyDouble" copy-double :void (storage storageptr) (src th-double-storage-ptr))))

(loop :for td :in *th-type-infos*
      :for prefix = (caddr td)
      :for real = (cadr td)
      :for acreal = (cadddr td)
      :do (loop :for fl :in *th-storage-functions*
                :for df = (make-defcfun-storage fl prefix real acreal)
                :do (eval df)))
