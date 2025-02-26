extends AbstractTest


const DialogueConstants = preload("res://addons/dialogue_manager/constants.gd")


func test_can_parse_conditions() -> void:
	var output = parse("
if StateForTests.some_property == 0:
	Nathan: It is 0.
elif StateForTests.some_property == 10:
	Nathan: It is 10.
else:
	Nathan: It is something else.
Nathan: After.")

	assert(output.errors.is_empty(), "Should have no errors.")

	# if
	var condition = output.lines["2"]
	assert(condition.type == DialogueConstants.TYPE_CONDITION, "Should be a condition.")
	assert(condition.next_id == "3", "Should point to next line.")
	assert(condition.next_conditional_id == "4", "Should reference elif.")
	assert(condition.next_id_after == "8", "Should reference after conditions.")

	# elif
	condition = output.lines["4"]
	assert(condition.type == DialogueConstants.TYPE_CONDITION, "Should be a condition.")
	assert(condition.next_id == "5", "Should point to next line.")
	assert(condition.next_conditional_id == "6", "Should reference elif.")
	assert(condition.next_id_after == "8", "Should reference after conditions.")

	# else
	condition = output.lines["6"]
	assert(condition.type == DialogueConstants.TYPE_CONDITION, "Should be a condition.")
	assert(condition.next_id == "7", "Should point to next line.")
	assert(condition.next_conditional_id == "8", "Should not reference further conditions.")
	assert(condition.next_id_after == "8", "Should reference after conditions.")


func test_ignore_escaped_conditions() -> void:
	var output = parse("
\\if this is dialogue.
\\elif this too.
\\else and this one.")

	assert(output.errors.is_empty(), "Should have no errors.")

	assert(output.lines["2"].type == DialogueConstants.TYPE_DIALOGUE, "Should be dialogue.")
	assert(output.lines["2"].text == "if this is dialogue.", "Should escape slash.")

	assert(output.lines["3"].type == DialogueConstants.TYPE_DIALOGUE, "Should be dialogue.")
	assert(output.lines["3"].text == "elif this too.", "Should escape slash.")

	assert(output.lines["4"].type == DialogueConstants.TYPE_DIALOGUE, "Should be dialogue.")
	assert(output.lines["4"].text == "else and this one.", "Should escape slash.")


func test_can_run_conditions() -> void:
	var resource = create_resource("
~ start
if StateForTests.some_property == 0:
	Nathan: It is 0.
elif StateForTests.some_property > 10:
	Nathan: It is more than 10.
else:
	Nathan: It is something else.")

	StateForTests.some_property = 0
	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "It is 0.", "Should match if condition.")

	StateForTests.some_property = 11
	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "It is more than 10.", "Should match elif condition.")

	StateForTests.some_property = 5
	line = await resource.get_next_dialogue_line("start")
	assert(line.text == "It is something else.", "Should match else.")


func test_can_parse_mutations() -> void:
	var output = parse("
set StateForTests.some_property = StateForTests.some_method(-10, \"something\")
do long_mutation()")

	assert(output.errors.is_empty(), "Should have no errors.")

	var mutation = output.lines["2"]
	assert(mutation.type == DialogueConstants.TYPE_MUTATION, "Should be a mutation.")

	mutation = output.lines["3"]
	assert(mutation.type == DialogueConstants.TYPE_MUTATION, "Should be a mutation.")


func test_can_run_mutations() -> void:
	var resource = create_resource("
~ start
set StateForTests.some_property = StateForTests.some_method(-10, \"something\")
set StateForTests.some_property += 5-10
set StateForTests.some_property *= 2
set StateForTests.some_property /= 2
Nathan: Pause the test.
do StateForTests.long_mutation()
Nathan: Done.")

	StateForTests.some_property = 0

	var line = await resource.get_next_dialogue_line("start")
	assert(StateForTests.some_property == StateForTests.some_method(-10, "something") + 5-10, "Should have updated the property.")

	var started_at: float = Time.get_unix_time_from_system()
	line = await resource.get_next_dialogue_line(line.next_id)
	var duration: float = Time.get_unix_time_from_system() - started_at
	assert(duration > 0.2, "Mutation should take some time.")


func test_can_run_mutations_with_typed_arrays() -> void:
	var resource = create_resource("
~ start
Nathan: {{StateForTests.typed_array_method([-1, 27], [\"something\"], [{ \"key\": \"value\" }])}}")

	var line = await resource.get_next_dialogue_line("start")
	assert(line.text == "[-1, 27][\"something\"][{ \"key\": \"value\" }]", "Should match output.")


func test_can_run_expressions() -> void:
	var resource = create_resource("
~ start
set StateForTests.some_property = 10 * 2-1.5 / 2 + (5 * 5)
Nathan: Done.")

	StateForTests.some_property = 0

	await resource.get_next_dialogue_line("start")
	assert(StateForTests.some_property == int(10 * 2-1.5 / 2 + (5 * 5)), "Should have updated the property.")



func test_can_use_extra_state() -> void:
	var resource = create_resource("
~ start
Nathan: {{extra_value}}
set extra_value = 10")

	var extra_state = { extra_value = 5 }

	var line = await resource.get_next_dialogue_line("start", [extra_state])
	assert(line.text == "5", "Should have initial value.")

	line = await  resource.get_next_dialogue_line(line.next_id, [extra_state])
	assert(extra_state.extra_value == 10, "Should have updated value.")
