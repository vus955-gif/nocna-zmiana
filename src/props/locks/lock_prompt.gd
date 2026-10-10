class_name LockPrompt
extends Interactable
## The use-probe's side of a gate lock: the line under the crosshair
## ("[E] Chain - break it with something heavy...") and what E does there,
## both asked of the lock.

var lock: GateLock = null


func prompt() -> String:
	return lock.prompt_text() if lock != null else ""


func can_interact(by: Node) -> bool:
	return enabled and lock != null and lock.can_use(by)


func interact(by: Node) -> void:
	if lock != null:
		lock.use(by)
	super(by)
