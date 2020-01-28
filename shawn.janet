(def- Event
  @{:update (fn [_ state])
    :watch (fn [_ state stream] [])
    :effect (fn [_ state stream])})

(defn event? [event]
  "Returns true if event is Event "
  (and (table? event)
       (event :update)
       (event :watch)
       (event :effect)))

(defn make-event
  "Creates new event"
  [{:update update-fn :watch watch-fn :effect effect-fn}]
  (def tab @{})
  (when update-fn (put tab :update update-fn))
  (when watch-fn (put tab :watch watch-fn))
  (when effect-fn (put tab :effect effect-fn))
  (table/setproto tab Event))

(defmacro defevent "Creates new named event"
  [name fns]
  ~(def ,name (,make-event ,fns)))

(defn- process-stream [self]
  (def stream (self :stream))
  (defn return [what] (array/push stream what))
  (while (not (empty? stream))
    (type (last stream))
    (match (array/pop stream)
      (event (event? event)) (:transact self event)
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
  (assert (event? event) (string "Only Events are transactable. Got: " event))
  (put self :old-state (table/clone (self :state)))
  (:update event (self :state))
  (match (:watch event (self :state) (self :stream))
    (arr (indexed? arr) (all event? arr))
    (array/concat (self :stream) (reverse arr))
    (eorf (or (event? eorf) (fiber? eorf)))
    (array/push (self :stream) eorf)
    (thread (= (type thread) :core/thread))
    (let [tid (string thread)]
      (:send thread tid)
      (array/push (self :stream) [tid thread]))
    bad (error (string "Watchable must be Event, Array of Events, Fiber or Thread. Got: " (type bad))))
  (:effect event (self :state) (self :stream))
  (:notify self)
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

