(import ../shawn :as s)

(s/defevent ZeroAmount 
  {:update (fn [_ state] (put state :amount 0))})

(s/defevent ZeroQuality
  {:update (fn [_ state] (put state :quality 0))})

(s/defevent IncreaseAmount
  {:update (fn [_ state] (update state :amount inc))})

(s/defevent DecreaseAmount
  {:update (fn [_ state] (update state :amount dec))})

(defn make-amount-adder [amount]
  (s/make-event {:update (fn [_ state] (update state :amount |(+ $ amount)))}))

(s/defevent ZeroAmountAndIncrease
  {:watch (fn [_ _ _] [ZeroAmount IncreaseAmount])})

(s/defevent PrepareState
  {:watch (fn [_ _ _] [ZeroAmountAndIncrease ZeroQuality])})

(s/defevent AddRandom
  {:watch (fn [_ _ _]
            (coro 
              (var res 0)
              (loop [_ :range [0 (* (math/random) 10_000_000)]] (+= res (math/random)))
              (loop [_ :range [0 (* (math/random) 10)]] (*= res (math/random)))
              (make-amount-adder res)))
   :effect (fn [_ _ _] (print "Hard computing"))})

(s/defevent AddManyRandoms
   {:watch (fn [_ _ _] (seq [_ :range [0 10]] AddRandom))})

(defn make-many-randoms-adder [count]
  (s/make-event {:watch (fn [_ _ _] (seq [_ :range [0 count]] AddRandom))}))

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
             (print "ss compute and add many random numbers to amount")
             (print "h print this help")
             (print "q quit console")
             (print))})

(s/defevent Exit
  {:effect (fn [_ _ _] (os/exit))})
