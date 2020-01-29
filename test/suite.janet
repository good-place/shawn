(use tester)
(import ../shawn :as shawn)
(import ../shawn/event :as event)

(deftest "store"
  (test "init-store" (shawn/init-store))
  (test "init-store with state"
        (= (get-in (shawn/init-store @{:counter 1}) [:state :counter]) 1))
  (test "init-store with wrong state"
        (match (protect (shawn/init-store {:counter 1}))
               [false (err (= err "State must be table"))] true ))
    (test "init-store with opts"
        (= ((shawn/init-store @{:counter 1} :tick 0.1) :tick) 0.1))
  (test "init-store with wrong opts"
        (match (protect (shawn/init-store @{:counter 1} :tick))
               [false (err (= err "Options must be even count pairs of key and value"))] true)))

(deftest "events"
  (test "make-event"
        (do
          (def e (event/make {:update (fn [_ state] state)}))
          (and (e :update)
               (e :watch)
               (e :effect))))
  (test "defevent"
        (do
          (event/defevent TestEvent {:update (fn [_ state] state)})
          (and (TestEvent :update)
               (TestEvent :watch)
               (TestEvent :effect))))
  (test "valid?"
        (do
          (event/defevent TestEvent {:update (fn [_ state] state)})
          (event/valid? TestEvent))))


(event/defevent TestUpdateEvent
  {:update (fn [_ state] (put state :test "Test"))})

(event/defevent TesttUpdateEvent
  {:update (fn [_ state] (update state :test |(string $ "t")))})

(def hard-work (os/sleep 0.001))
# Could be used as worker template
(defn worker [m]
  (with [_ [:fin (thread/receive math/inf)] |(:send m $)]
     hard-work
     (:send m TesttUpdateEvent)
     hard-work))

(deftest "transact"
  (test "one update event"
        (let [store (shawn/init-store)]
          (:transact store TestUpdateEvent)
          (deep= (store :state) @{:test "Test"})))
  (test "one watch event"
        (let [store (shawn/init-store)]
          (event/defevent TestWatchEvent {:watch (fn [_ _ _] TestUpdateEvent)})
          (:transact store TestWatchEvent)
          (deep= (store :state) @{:test "Test"})))
  (test "one effect event"
        (let [store (shawn/init-store)]
          (var ok false)
          (event/defevent TestEffectEvent {:effect (fn [_ state _] (set ok true))})
          (:transact store TestEffectEvent)
          ok))
  (test "many watch events"
       (let [store (shawn/init-store)]
         (event/defevent TestWatchEvent {:watch (fn [_ _ _] [TestUpdateEvent TesttUpdateEvent TesttUpdateEvent])})
         (:transact store TestWatchEvent)
         (deep= (store :state) @{:test "Testtt"})))
  (test "one fiber event"
        (let [store (shawn/init-store)]
          (event/defevent TestFiberEvent
            {:watch
             (fn [_ _ _]
               (coro
                (yield TestUpdateEvent)
                (for _ 0 5 (yield TesttUpdateEvent))
                TesttUpdateEvent))})
          (:transact store TestFiberEvent)
          (deep= (store :state) @{:test "Testtttttt"})))
  (test "one thread event"
        (let [store (shawn/init-store)]
          (event/defevent TestThreadEvent {:watch (fn [_ _ _] (thread/new worker))})
          (:transact store TestUpdateEvent)
          (for _ 0 5 (:transact store TestThreadEvent))
          (:transact store (event/make {:update (fn [_ state] (put state :fest "Fest"))}))
          (deep= (store :state) @{:test "Testttttt" :fest "Fest"})))
  (test "combined event"
        (let [store (shawn/init-store)]
          (var ok false)
          (event/defevent CombinedEvent {:update (fn [_ state] (put state :test "Test"))
                                         :watch (fn [_ _ _] TesttUpdateEvent)
                                         :effect (fn [_ state _] (set ok true))})
          (:transact store CombinedEvent)
          (and ok (deep= (store :state) @{:test "Testt"}))))
  (test "error event"
        (let [store (shawn/init-store)]
          (match (protect (:transact store {}))
                 [false err] (string/has-prefix? "Only Events are transactable. Got: " err))))
  (test "watch error event"
        (let [store (shawn/init-store)]
          (match (protect (:transact store (event/make {:watch (fn [_ _ _] {})})))
                 [false err] (string/has-prefix? "Only Event, Array of Events, Fiber and Thread are watchable. Got:" err)))))

(deftest "observers"
  (test "observe"
        (let [store (shawn/init-store)]
          (var ok false)
          (:observe store (fn [_ new-state] (set ok (= (new-state :test) "Test"))))
          (event/defevent TestUpdateEvent {:update (fn [_ state] (put state :test "Test"))})
          (:transact store TestUpdateEvent)
          ok)))
