(def- grammar 
  ~{:spc " "
    :num (cmt (<- (some (range "09")) :num) ,scan-number)
    :inc (* "+" -1 (constant :inc) (constant 1))
    :dec (* "-" -1 (constant :dec) (constant 1))
    :pinc (* "+" :spc (constant :inc) :num)
    :pdec (* "-" :spc (constant :dec) :num)
    :zero "0"
    :rnd (* "r" -1 (constant :rnd) (constant 1))
    :prnd (* "r" :spc (constant :rnd) :num)
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
             :print
             :help
             :exit)})

(defn parse-command [s]
  (peg/match grammar s))

