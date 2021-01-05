(def- grammar
  ~{:spc " "
    :num (cmt (<- (some (range "09")) :num) ,scan-number)
    :inc (* "+" -1 (constant :inc) (constant 1))
    :dec (* "-" -1 (constant :dec) (constant 1))
    :pinc (* "+" :spc (constant :inc) :num)
    :pdec (* "-" :spc (constant :dec) :num)
    :zero (* "0" -1 (constant :zero))
    :rnd (* "r" -1 (constant :rnd) (constant 1))
    :prnd (* "r" :spc (constant :rnd) :num)
    :trnd (* "t" -1 (constant :trnd) (constant 1))
    :ptrnd (* "t" :spc (constant :trnd) :num)
    :print (* "p" -1 (constant :print))
    :help (* "h" -1 (constant :help))
    :exit (* "q" -1 (constant :exit))
    :main (+ :inc
             :dec
             :pinc
             :pdec
             :zero
             :rnd
             :prnd
             :trnd
             :ptrnd
             :print
             :help
             :exit)})

(defn parse-command [s]
  (peg/match grammar s))
