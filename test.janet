(import shawn :as s)
(import events :as e)

(:observe s/Store (fn [os ns] (when (< 1 (ns :amount)) (print "Oh big amount"))))
(:observe s/Store (fn [os ns] 
                  (when (and (os :amount) (ns :amount))
                    (when (< (os :amount) (ns :amount)) (print "Oh yes amount went up"))
                    (when (> (os :amount) (ns :amount)) (print "Oh no amount went down")))))

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
