extends Resource
## Editable presentation/observation contract, independent of combat states.
@export var id: StringName
@export var title: String
@export_multiline var text: String
@export_enum("always", "bonfire", "target", "combat", "wounded", "gate") var context: String = "always"
@export var completion_event: StringName
@export var skippable: bool = true
