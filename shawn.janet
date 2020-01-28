(defn- watchable-error [watchable]
  (error (string "Watchable must be Event, Array of Events or Fiber. Got: " (type watchable))))

(def- Event
  @{:update (fn [_ state])
    :watch (fn [_ state stream] [])
    :effect (fn [_ state stream])})

(defn event? [e]
  (and (dictionary? e)
       (e :update)
       (e :watch)
       (e :effect)))

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

(defevent Empty {})

(defn- process-stream [self]
  (def stream (self :stream))
  (while (not (empty? stream))
    (let [w (array/pop stream)]
      (match w
               (event (event? event)) (:transact self w)
               (fiber (fiber? fiber) (= :dead (fiber/status fiber))) nil
               (fiber (fiber? fiber) (= :alive (fiber/status fiber))) (array/push stream fiber)
               (fiber (fiber? fiber))
                 (do (array/push stream fiber)
                     (:transact self (resume fiber)))))))

(defn- process-threads [self]
  (when (not (empty? (self :threads)))
    (match (protect (thread/receive (self :tick)))
           [false _] (:transact self Empty)
           [true (event (event? event))] (:transact self event)
           [true [(msg (= msg :fin)) tid]]
           (let [ti (find-index |(= (first $) tid) (self :threads))
                 t (get-in self [:threads ti 1])]
             (:close t)
             (array/remove (self :threads) ti)
             (:transact self Empty)))))

(defn- notify [self]
  (unless (deep= (self :old-state) (self :state))
    (each o (self :observers)
      (o (self :old-state) (self :state)))))

(defn- transact [self event]
  (assert (event? event) (string "Only Events are transactable. Got: " event))
  (put self :old-state (table/clone (self :state)))
  (:update event (self :state))
  (let [watchable (:watch event (self :state) (self :stream))]
    (cond
     (event? watchable)
     (array/push (self :stream) watchable)
     (and (indexed? watchable) (all event? watchable))
     (array/concat (self :stream) (reverse watchable))
     (or (fiber? watchable))
     (array/push (self :stream) watchable)
     (= :core/thread (type watchable))
     (let [tid (string watchable)]
       (:send watchable tid)
       (array/push (self :threads) [tid watchable]))
     (watchable-error watchable)))
  (:effect event (self :state) (self :stream))
  (:notify self)
  (:process-stream self)
  (:process-threads self)
  nil)

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
    :process-threads process-threads
    :notify notify
    :observe observe})

(defn init-store [&opt state store]
  (default state @{})
  (default store @{:state state})
  (table/setproto store Store))

