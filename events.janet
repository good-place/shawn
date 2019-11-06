(import shawn :as s)

(s/defevent ZeroAmount 
  {:update (fn [_ state] (put state :amount 0))})

(s/defevent ZeroQuality
  {:update (fn [_ state] (put state :quality 0))})

(s/defevent IncreaseAmount
  {:update (fn [_ state] (update state :amount inc))})

(s/defevent DecreaseAmount
  {:update (fn [_ state] (update state :amount dec))})

(s/defevent ZeroAmountAndIncrease
  {:watch (fn [_ _ _] [ZeroAmount IncreaseAmount])})

(s/defevent PrepareState
  {:watch (fn [_ _ _] [ZeroAmountAndIncrease ZeroQuality])})

(s/defevent AddRandomAfterWhile
  {:watch (fn [_ _ _]
            (coro (def num (math/random))
                  (loop [i :range [0 100000000]] (* i i))
                  (yield (s/make-event {:update (fn [_ state] (update state :amount |(+ $ num)))}))))
   :effect (fn [_ _ _] (print "Hard computing"))})

(s/defevent UnknownCommand 
  {:effect (fn [_ _ _] (print "Unknown command"))})

(s/defevent PrintHelp
  {:effect (fn [_ _ _]
             (print)
             (print "Help")
             (print "+ add 1 to amount")
             (print "- substract 1 from amount")
             (print "0 make amount zero")
             (print "s compute and add random number to amount")
             (print "h print this help")
             (print "q quit console")
             (print))})

(s/defevent Exit
  {:effect (fn [_ _ _] (os/exit))})
