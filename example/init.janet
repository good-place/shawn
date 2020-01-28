(import shawn)
(import example/events)
(import example/parser)

(def store (shawn/init-store))

(:observe store (fn [_ ns] (when (< 1 (ns :amount)) (print "Oh yes big amount"))))
(:observe store (fn [_ ns] (when (> 0 (ns :amount)) (print "Oh no negative amount"))))
(:observe store (fn [os ns]
                  (when (and (os :amount) (ns :amount))
                    (when (< (os :amount) (ns :amount)) (print "Oh yes amount went up"))
                    (when (> (os :amount) (ns :amount)) (print "Oh no amount went down")))))

(:transact store events/PrepareState)
(while true
  (def readout (-> "Command [+ - 0 r t p q h]: " getline string/trim))
  (def event
    (if-let [[command amount] (parser/parse-command readout)]
      (case command
        :inc (events/increase-amount amount)
        :dec (events/decrease-amount amount)
        :zero events/ZeroAmount
        :rnd (events/add-many-randoms amount)
        :trnd (events/add-many-thread-randoms amount)
        :print events/PrintState
        :help events/PrintHelp
        :exit events/Exit)
      (events/unknown-command readout)))
  (:transact store event))
