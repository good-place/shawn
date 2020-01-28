(def- Event
  @{:update (fn [_ state])
    :watch (fn [_ state stream] [])
    :effect (fn [_ state stream])})

(defn valid? [event]
  "Returns true if event is valid Event "
  (truthy?
    (and (table? event)
         (event :update)
         (event :watch)
         (event :effect))))

(defn make
  "Creates new event"
  [{:update update-fn :watch watch-fn :effect effect-fn}]
  (def tab @{})
  (when update-fn (put tab :update update-fn))
  (when watch-fn (put tab :watch watch-fn))
  (when effect-fn (put tab :effect effect-fn))
  (table/setproto tab Event))

(defmacro defevent "Creates new named event"
  [name fns]
  ~(def ,name (,make ,fns)))
