(import shawn)
(import shawn/event)

(event/defevent ZeroAmount
  {:update (fn [_ state] (put state :amount 0))})

(event/defevent ZeroQuality
  {:update (fn [_ state] (put state :quality 0))})

(defn increase-amount [amount]
  (event/make {:update (fn [_ state] (update state :amount |(+ amount $)))}))

(defn decrease-amount [amount]
  (event/make {:update (fn [_ state] (update state :amount |(- $ amount)))}))

(event/defevent ZeroAmountAndIncrease
  {:watch (fn [_ _ _] [ZeroAmount (increase-amount 1)])})

(event/defevent PrepareState
  {:watch (fn [_ _ _] [ZeroAmountAndIncrease ZeroQuality])})

(defn worker [m]
  (def tid (thread/receive math/inf))
  (var res 0)
  (loop [_ :range [0 (* (math/random) 100_000_000)]] (+= res (math/random)))
  (:send m (increase-amount res))
  (:send m [:fin tid]))

(event/defevent AddThreadRandom
  {:watch (fn [_ _ _] (thread/new worker))
   :effect (fn [_ _ _] (print "Hard computing"))})

(event/defevent AddRandom
  {:watch
   (fn [_ _ _]
     (coro
       (var res 0)
       (loop [_ :range [0 (* (math/random) 10_000_000)]] (+= res (math/random)))
       (increase-amount res)))
   :effect (fn [_ _ _] (print "Hard computing"))})

(defn add-many-randoms [amount]
  (event/make {:watch (fn [_ _ _] (seq [_ :range [0 amount]] AddRandom))}))

(defn add-many-thread-randoms [amount]
  (event/make {:watch (fn [_ _ _] (seq [_ :range [0 amount]] AddThreadRandom))}))

(event/defevent PrintState
  {:effect (fn [_ state _] (prin "State: ") (pp state))})

(event/defevent PrintHelp
  {:effect (fn [_ _ _]
             (print
```

Help:
0 make amount zero
+ [num] add 1 or num to amount
- [num] substract 1 or num from amount
r [num] compute and add 1 or num random numbers to amount
t [num] compute and add 1 or num random numbers to amount in threads
p print state
h print this help
q quit console

```
            ))})

(defn unknown-command [command]
  (event/make {:watch (fn [_ _ _ ] PrintHelp)
                 :effect (fn [_ _ _] (print "Unknown command: " command))}))

(event/defevent Exit {:effect (fn [_ _ _] (print "Bye!") (os/exit))})
