(import shawn/event :as event)

(defn- process-stream [self]
  (def stream (self :stream))
  (defn return [what] (array/push stream what))
  (while (not (empty? stream))
    (type (last stream))
    (match (array/pop stream)
      (event (event/valid? event)) (:transact self event)
      (fiber (fiber? fiber) (= (fiber/status fiber) :alive)) (return fiber)
      (fiber (fiber? fiber) (some |(= (fiber/status fiber) $) [:pending :new]))
      (do (return fiber) (:transact self (resume fiber)))
      [id (thread (= (type thread) :core/thread))]
      (match (protect (thread/receive (self :tick)))
        [false _] (do (return [id thread]))
        [true [(msg (= msg :fin)) tid]]
        (if (= id tid) (:close thread)
          (let [t (find |(= (first $) tid) (return [id thread]))]
            (:close t)))
        [true event] (do (return [id thread]) (:transact self event))))))

(defn- notify [self]
  (unless (deep= (self :old-state) (self :state))
    (each o (self :observers)
      (o (self :old-state) (self :state)))))

(defn- transact [self event]
  (assert (event/valid? event) (string "Only Events are transactable. Got: " event))
  (put self :old-state (table/clone (self :state)))
  (:update event (self :state))
  (:notify self)
  (match (:watch event (self :state) (self :stream))
    (arr (indexed? arr) (all event/valid? arr))
    (array/concat (self :stream) (reverse arr))
    (eorf (or (event/valid? eorf) (fiber? eorf)))
    (array/push (self :stream) eorf)
    (thread (= (type thread) :core/thread))
    (let [tid (string thread)]
      (:send thread tid)
      (array/push (self :stream) [tid thread]))
    bad (error (string "Only Event, Array of Events, Fiber and Thread are watchable. Got:" (type bad))))
  (:effect event (self :state) (self :stream))
  (:process-stream self))

(defn- observe [self observer]
  (array/push (self :observers) observer))

(def Store
  @{:transact transact
    :tick (/ 60)
    :old-state nil
    :stream @[]
    :fibers @[]
    :threads @[]
    :observers @[]
    :process-stream process-stream
    :notify notify
    :observe observe})

(defn init-store [&opt state store]
  (default state @{})
  (default store @{:state state})
  (table/setproto store Store))

