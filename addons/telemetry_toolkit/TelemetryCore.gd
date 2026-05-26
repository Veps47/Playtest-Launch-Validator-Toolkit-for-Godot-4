## TelemetryCore.gd — Автономный синглтон неблокирующего сбора телеметрии.
extends Node

const BUFFER_DIR := "user://telemetry_buffer/"

# Потокобезопасная очередь событий
var _queue: Array[Dictionary] = []
var _mutex: Mutex
var _semaphore: Semaphore
var _thread: Thread

# Управление жизненным циклом потока
var _is_exiting := false
var _session_id := ""

func _ready() -> void:
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_thread = Thread.new()
	
	_init_storage()
	_session_id = _generate_session_id()
	
	# Запуск фонового воркера для сброса логов на диск
	_thread.start(Callable(self, "_thread_worker"))
	
	# Фиксация системных метрик старта сессии
	track_event("session_start", {
		"os": OS.get_name(),
		"locale": OS.get_locale(),
		"screen_resolution": str(DisplayServer.window_get_size()),
		"is_debug": OS.is_debug_build()
	})


## Публичный API для вызова из любой точки игры
func track_event(event_type: String, payload: Dictionary = {}) -> void:
	var event := {
		"session_id": _session_id,
		"timestamp": Time.get_unix_time_from_system(),
		"type": event_type,
		"payload": payload
	}
	
	# Быстропуш в массив и дарим носок мьютексу
	_mutex.lock()
	_queue.append(event)
	_mutex.unlock()
	
	# Зовём работать фоновый поток
	_semaphore.post()


## События воронки (прохождение туториала, вехи)
func track_funnel(step_id: String, status: String, extra: Dictionary = {}) -> void:
	track_event("funnel_step", {
		"step_id": step_id,
		"status": status,
		"extra": extra
	})


## Точка фиксации раннего дропоффа
func track_early_churn(last_scene: String, gameplay_duration_sec: float) -> void:
	track_event("early_churn_snapshot", {
		"last_visible_scene": last_scene,
		"duration_seconds": gameplay_duration_sec,
		"is_refund_risk": gameplay_duration_sec < 7200.0 # Менее 120 минут (окно возврата Steam)
	})


## Инициализация локального буфера
func _init_storage() -> void:
	if not DirAccess.dir_exists_absolute(BUFFER_DIR):
		DirAccess.make_dir_absolute(BUFFER_DIR)


## Генерация уникального ID сессии (без внешних зависимостей)
func _generate_session_id() -> String:
	var system_time := str(Time.get_unix_time_from_system()).md5_text().substr(0, 8)
	var random_part := str(randi()).md5_text().substr(0, 8)
	return "sn_session_%s_%s" % [system_time, random_part]


## Рабочий цикл фонового потока
func _thread_worker() -> void:
	while true:
		_semaphore.wait() # Спим, пока нет событий
		
		_mutex.lock()
		if _is_exiting and _queue.is_empty():
			_mutex.unlock()
			break # Корректный выход при закрытии игры
			
		if _queue.is_empty():
			_mutex.unlock()
			continue
			
		# Хапаем весь накопленный батч
		var batch_to_write := _queue.duplicate()
		_queue.clear()
		_mutex.unlock()
		
		_flush_batch_to_disk(batch_to_write)


## Запись пакета данных в жсон
func _flush_batch_to_disk(batch: Array[Dictionary]) -> void:
	if batch.is_empty():
		return
		
	# Имя файла на основе временной метки батча
	var timestamp := str(Time.get_ticks_msec())
	var file_path := BUFFER_DIR + "batch_%s_%s.json" % [_session_id, timestamp]
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(batch))
		file.close()
	else:
		push_error("TelemetryCore: Failed to write telemetry batch to " + file_path)


## Гарантия сохранения данных при закрытии игры
func _exit_tree() -> void:
	# Фиксируем финальное событие перед закрытием
	track_event("session_end", {
		"total_runtime": Time.get_ticks_msec() / 1000.0
	})
	
	_mutex.lock()
	_is_exiting = true
	_mutex.unlock()
	
	# Пинаем поток, чтобы он дозаписал остатки из очереди
	_semaphore.post()
	
	# Блок основного потока, пока фоновый поток не завершит запись
	if _thread.is_started():
		_thread.wait_to_finish()
