(import shawn :as s)
(import events :as e )

(:observe s/Store (fn [old-state new-state] (when (< 1 (new-state :amount)) (print "Oh big amount"))))
(:observe s/Store (fn [old-state new-state] 
                  (when (and (old-state :amount) (new-state :amount))
                                                     (when (< (old-state :amount) (new-state :amount))
                                                      (print "Oh yes amount went up"))
                                                     (when (> (old-state :amount) (new-state :amount))
                                                      (print "Oh no amount went down")))))
(:transact s/Store e/PrepareState)
(while true 
  (def event 
    (case (string/trim (getline "Command [+ - 0 q s h]: "))
      "+" e/IncreaseAmount
      "-" e/DecreaseAmount
      "0" e/ZeroAmount
      "s" e/AddRandomAfterWhile
      "h" e/PrintHelp
      "q" e/Exit
      e/UnknownCommand))
  (:transact s/Store event)
  (pp (s/Store :state)))
