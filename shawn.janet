(import shawn/event :as event)

(defn- _process-stream [self]
  (def stream (self :_stream))
  (defn return [what] (array/insert stream 0 what))
  (while (not (empty? stream))
    (match (array/pop stream)
      (event (event/valid? event)) (:transact self event)
      (fiber (fiber? fiber) (= (fiber/status fiber) :alive)) (return fiber)
      (fiber (fiber? fiber) (some |(= (fiber/status fiber) $) [:pending :new]))
      (do (return fiber) (:transact self (resume fiber)))
      [id (thread (= (type thread) :core/thread))]
      (match (protect (thread/receive (self :tick)))
        [false _] (do (return [id thread]))
        [true [(msg (= msg :fin)) tid]]
        (if (= id tid)
          (:close thread)
          (let [t ((find |(= (first $) tid) (return [id thread])))]
            (:close t)))
        [true event] (do (return [id thread]) (:transact self event))))))

(defn- _notify [self]
  (defer (put self :_old-state nil)
    (unless (deep= (self :_old-state) (self :state))
      (each o (self :_observers)
        (o (self :_old-state) (self :state))))))

(defn transact
  "Transacts Event into Store. Has two parameters:\n
   store: Store to which we are transacting\n
   event: Event we are transacting. Throws when the Event is invalid\n
   This functions is called when you call :transact method on Store"
  [store event]
  (assert (event/valid? event) (string "Only Events are transactable. Got: " event))
  (put store :_old-state (table/clone (store :state)))
  (:update event (store :state))
  (:_notify store)
  (match (:watch event (store :state) (store :_stream))
    (arr (indexed? arr) (all event/valid? arr))
    (array/concat (store :_stream) (reverse arr))
    (eorf (or (event/valid? eorf) (fiber? eorf)))
    (array/push (store :_stream) eorf)
    (thread (= (type thread) :core/thread))
    (let [tid (string thread)]
      (:send thread tid)
      (array/push (store :_stream) [tid thread]))
    bad (error (string "Only Event, Array of Events, Fiber and Thread are watchable. Got:" (type bad))))
  (:effect event (store :state) (store :_stream))
  (:_process-stream store))

(defn observe
  "Adds observer function to store. Has two parameters:\n
   store: Store to which observer is added
   observer: observer function\n
   Observed functions are called everytime state
   changes with two parameters:\n
   old-state: state before the change\n
   new-state: state after the change\n
   This function is called when you call :observe method on Store"
  [store observer]
  (array/push (store :_observers) observer))

(def Store
  "Store prototype. It has two public methods:\n
  (:transact store event): transacts given Event\n
  (:observe store obserer): adds observer to the Store"
  @{:tick (/ 60)
    :transact transact
    :observe observe
    :_old-state nil
    :_stream @[]
    :_observers @[]
    :_process-stream _process-stream
    :_notify _notify})

(defn init-store
  "Factory function for creating new Store with two optional parameters:\n
   state: initial state for the Store. Default @{}. Throws when state is not table\n
   opts: pairs with options for the Store, they are merged after setting Store prototype.
   Throws when opts do not have even count."
  [&opt state & opts]
  (default state @{})
  (assert (table? state) "State must be tuple")
  (assert (even? (length opts)) "Options must be even count pairs of key and value")
  (-> @{:state state} (table/setproto Store) (merge-into (table ;opts))))

