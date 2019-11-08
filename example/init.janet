(import ../shawn :as s)
(import ./events :as e)
(import ./parser :as p)

(:observe s/Store (fn [os ns] (when (< 1 (ns :amount)) (print "Oh yes big amount"))))
(:observe s/Store (fn [os ns] (when (> 0 (ns :amount)) (print "Oh no negative amount"))))
(:observe s/Store (fn [os ns] 
                  (when (and (os :amount) (ns :amount))
                    (when (< (os :amount) (ns :amount)) (print "Oh yes amount went up"))
                    (when (> (os :amount) (ns :amount)) (print "Oh no amount went down")))))

(:transact s/Store e/PrepareState)
(while true 
  (def readout (-> "Command [+ - 0 r p q h]: " getline string/trimr string/triml))
  (def event 
    (if-let [[command amount] (p/parse-command readout)]
      (case command
        :inc (e/increase-amount amount)
        :dec (e/decrease-amount amount)
        :zero e/ZeroAmount
        :rnd (e/add-many-randoms amount)
        :print e/PrintState
        :help e/PrintHelp
        :exit e/Exit)
      (e/unknown-command readout)))
  (:transact s/Store event))
