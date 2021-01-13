(import /shawn)
(import /shawn/event)

(event/defevent ZeroAmount {:update (fn [_ state] (put state :amount 0))})

(event/defevent ZeroQuality {:update (fn [_ state] (put state :quality 0))})

(defn increase-amount [amount]
  (event/make {:update (fn [_ state] (update state :amount |(+ amount $)))}))

(defn decrease-amount [amount]
  (event/make {:update (fn [_ state] (update state :amount |(- $ amount)))}))

(event/defevent ZeroAmountAndIncrease
                {:watch (fn [&] [ZeroAmount (increase-amount 1)])})

(event/defevent PrepareState
                {:watch (fn [&] [ZeroAmountAndIncrease ZeroQuality])})

(event/defevent MillionDown {:effect (fn [&] (print ">>>>> Million down"))})

(event/defevent AddRandom
                {:watch
                 (fn [&]
                   (coro
                     (var res 0)
                     (loop [_ :range [0 (* (math/random) 1_000_000)]]
                       (+= res (math/random)))
                     (increase-amount res)))
                 :effect (fn [&] (print "Hard computing"))})

(defn add-many-randoms [amount]
  (event/make {:watch (fn [&] (seq [_ :range [0 amount]] AddRandom))}))

(event/defevent PrintState
                {:effect (fn [_ state _] (prin "State: ") (pp state))})

(event/defevent
  PrintHelp
  {:effect (fn [&]
             (print
               ```
               Available commands:
                 0 make amount zero
                 + [num] add 1 or num to amount
                 - [num] substract 1 or num from amount
                 r [num] compute and add 1 or num random numbers to amount
                 p print state
                 h print this help
                 q quit console
               ```))})

(defn unknown-command [command]
  (event/make {:watch (fn [&] PrintHelp)
               :effect (fn [&] (print "Unknown command: " command))}))

(event/defevent Exit {:effect (fn [&] (print "Bye!") (os/exit))})
