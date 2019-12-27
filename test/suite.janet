(use tester)
(import ../shawn :as shawn)

(defn- pending [message]
  (print "\nPending: " message)
  :pending)

(deftest "events"
  (test "make-event" 
        (do 
          (def event (shawn/make-event {:update (fn [_ state] state)}))
          (and (event :update)
               (event :watch)
               (event :effect))))
  (test "defevent" 
        (do 
          (shawn/defevent TestEvent {:update (fn [_ state] state)})
          (and (TestEvent :update)
               (TestEvent :watch)
               (TestEvent :effect))))
  (test "event?"
        (do 
          (shawn/defevent TestEvent {:update (fn [_ state] state)})
          (shawn/event? TestEvent))))

(deftest "transact"
  (test "one update event"
        (do 
          (def store (shawn/init-store))
          (shawn/defevent TestUpdateEvent {:update (fn [_ state] (put state :test "Test"))})
          (:transact store TestUpdateEvent)
          (deep= (store :state) @{:test "Test"})))
  (test "one watch event"
        (do 
          (def store (shawn/init-store))
          (shawn/defevent TestUpdateEvent {:update (fn [_ state] (put state :test "Test"))})
          (shawn/defevent TestWatchEvent {:watch (fn [_ _ _] TestUpdateEvent)})
          (:transact store TestWatchEvent)
          (deep= (store :state) @{:test "Test"})))
  (test "one effect event"
        (do 
          (def store (shawn/init-store))
          (shawn/defevent TestEffectEvent {:effect (fn [_ state _] (error "Effect triggered"))})
          (try 
            (:transact store TestEffectEvent)
            ([message] (= message "Effect triggered")))))
  (test "many watch events"
        (do 
          (def store (shawn/init-store))
          (shawn/defevent TestUpdateEvent {:update (fn [_ state] (put state :test "Test"))})
          (shawn/defevent TesttUpdateEvent {:update (fn [_ state] (update state :test |(string $ "t")))})
          (shawn/defevent TestWatchEvent {:watch (fn [_ _ _] [TestUpdateEvent TesttUpdateEvent TesttUpdateEvent])})
          (:transact store TestWatchEvent)
          (deep= (store :state) @{:test "Testtt"})))
  (test "one fiber event"
        (do 
          (def store (shawn/init-store))
          (shawn/defevent TestUpdateEvent {:update (fn [_ state] (put state :test "Test"))})
          (shawn/defevent TesttUpdateEvent {:update (fn [_ state] (update state :test |(string $ "t")))})
          (shawn/defevent TestFiberEvent 
            {:watch
             (fn [_ _ _]
               (coro 
                 (shawn/make-event {:watch 
                                    (fn [_ _ _] 
                                      [TestUpdateEvent TesttUpdateEvent TesttUpdateEvent TesttUpdateEvent])})))})
          (:transact store TestFiberEvent)
          (deep= (store :state) @{:test "Testttt"})))
  (test "combined event"
        (pending "combined event")))

(deftest "observers"
  (test "observe" 
        (do 
          (def store (shawn/init-store))
          (:observe store (fn [old-state new-state] (when (= (new-state :test) "Test") (error "State should contain test"))))
          (shawn/defevent TestUpdateEvent {:update (fn [_ state] (put state :test "Test"))})
          (try
            (:transact store TestUpdateEvent)
            ([message] (= message "State should contain test"))))))
