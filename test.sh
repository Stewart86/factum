#!/bin/bash

# Test script for the TODO application

# Ensure that the script exits on first error
set -e

# Variables
TODO_CMD="./todo.sh"
TEST_DB="test_todo.db"
ORIGINAL_DB="todo.db"

# Function to reset the test environment
reset_test_environment() {
  echo "Resetting test environment..."
  # Backup the original database
  if [ -f "$ORIGINAL_DB" ]; then
    mv "$ORIGINAL_DB" "${ORIGINAL_DB}.bak"
  fi
  # Remove any existing test database
  [ -f "$TEST_DB" ] && rm "$TEST_DB"
  # Create an empty database
  touch "$TEST_DB"
  # Ensure the TODO script uses the test database
  export DATABASE="$TEST_DB"
  # Initialize the database
  $TODO_CMD --help >/dev/null
}

# Function to restore the original environment
restore_environment() {
  echo "Restoring original environment..."
  # Remove the test database
  [ -f "$TEST_DB" ] && rm "$TEST_DB"
  # Restore the original database
  if [ -f "${ORIGINAL_DB}.bak" ]; then
    mv "${ORIGINAL_DB}.bak" "$ORIGINAL_DB"
  fi
  # Unset the test database variable
  unset DATABASE
}

# Function to run a test case
run_test() {
  test_description="$1"
  test_command="$2"
  expected_result="$3"

  echo "----------------------------------------"
  echo "Test: $test_description"
  echo "Executing: $test_command"

  # Execute the test command and capture output
  output=$(eval "$test_command" 2>&1 || true)

  # Check if expected result is in the output using fixed string matching
  if echo "$output" | grep -Fq "$expected_result"; then
    echo "✅ Test passed."
  else
    echo "❌ Test failed."
    echo "Expected to find: $expected_result"
    echo "Actual output:"
    echo "$output"
    # Restore environment and exit
    restore_environment
    exit 1
  fi
}

# Main test execution
main() {
  # Reset the test environment
  reset_test_environment

  # Begin tests
  echo "Starting tests..."

  ####################################################
  # 1. Adding Tasks
  ####################################################
  # 1.1 Add Task with Only Title
  run_test "Add Task with Only Title" \
    "$TODO_CMD --add -t 'Task with only title'" \
    "✅ Task added successfully!"

  # 1.2 Add Task with All Fields
  run_test "Add Task with All Fields" \
    "$TODO_CMD --add -t 'Complete Project Report' -d 'Finalize the project report and submit it to the manager.' -D '2023-11-30' -e '2023-12-31' -r '* * 1-5' --yes " \
    "✅ Task added successfully!"

  # 1.3 Add Task with Interval Days
  run_test "Add Task with Interval Days" \
    "$TODO_CMD --add -t 'Biweekly Team Meeting' -D '2023-11-01' -i '14' --yes" \
    "✅ Task added successfully!"

  # 1.4 Add Task with Invalid Due Date
  run_test "Add Task with Invalid Due Date" \
    "$TODO_CMD --add -t 'Task with invalid date' -D '2023-13-01'" \
    "❌ Invalid due date format. Please use YYYY-MM-DD."

  # 1.5 Add Task with Invalid Recurring Expression
  run_test "Add Task with Invalid Recurring Expression" \
    "$TODO_CMD --add -t 'Task with invalid recurrence' -r 'invalid_expression'" \
    "❌ Invalid recurring expression."

  # 1.6 Add Task with Special Characters in Title and Description
  run_test "Add Task with Special Characters" \
    "$TODO_CMD --add -t \"Review client's feedback\" -d \"Check the client's comments and update accordingly.\"" \
    "✅ Task added successfully!"

  # 1.7 Add Task Without Title
  run_test "Add Task Without Title" \
    "$TODO_CMD --add -d 'Description without title'" \
    "❌ Title is required."

  # 1.8 Add Task with Whitespace Title
  run_test "Add Task with Whitespace Title" \
    "$TODO_CMD --add -t '   '" \
    "❌ Title is required."

  # 1.9 Add Task with Emoji in Title
  run_test "Add Task with Emoji in Title" \
    "$TODO_CMD --add -t 'Task with emoji 😊'" \
    "✅ Task added successfully!"

  # 1.10 Add Task with Invalid Date Format
  run_test "Add Task with Invalid Date Format" \
    "$TODO_CMD --add -t 'Invalid Date Format Task' -D '2023/01/01'" \
    "❌ Invalid due date format. Please use YYYY-MM-DD."

  ####################################################
  # 2. Listing Tasks
  ####################################################
  # 2.1 List Pending Tasks
  run_test "List Pending Tasks" \
    "$TODO_CMD --list pending" \
    "┌────┬────┬───"

  # 2.2 List Completed Tasks
  run_test "List Completed Tasks" \
    "$TODO_CMD --list completed" \
    "ℹ️ No tasks found."

  # 2.3 List All Tasks
  run_test "List All Tasks" \
    "$TODO_CMD --list all" \
    "┌────┬────┬───"

  ####################################################
  # 3. Updating Tasks
  ####################################################
  # Assume task ID 1 exists from previous tests
  # 3.1 Update Task Title and Description
  run_test "Update Task Title and Description" \
    "$TODO_CMD --update 1 -t 'Updated Task Title' -d 'Updated task description.'" \
    "✅ Task updated successfully!"

  # 3.2 Update Task Due Date
  run_test "Update Task Due Date" \
    "$TODO_CMD --update 1 -D '2023-12-15'" \
    "✅ Task updated successfully!"

  # 3.3 Update Task to Add Recurrence
  run_test "Update Task to Add Recurrence" \
    "$TODO_CMD --update 1 -r '* * 1-5'" \
    "✅ Task updated successfully!"

  # 3.4 Update Task with Invalid Interval Days
  run_test "Update Task with Invalid Interval Days" \
    "$TODO_CMD --update 1 -i 'invalid_interval'" \
    "❌ Interval days must be a positive integer."

  # 3.5 Update Task to Remove Recurrence
  run_test "Update Task to Remove Recurrence" \
    "$TODO_CMD --update 1 -r 'none' -i ''" \
    "✅ Task updated successfully!"

  # 3.6 Update Non-Existent Task
  run_test "Update Non-Existent Task" \
    "$TODO_CMD --update 999 -t 'Non-existent Task'" \
    "❌ Task ID 999 does not exist."

  ####################################################
  # 4. Deleting Tasks
  ####################################################
  # 4.1 Delete a Task without Confirmation
  run_test "Delete a Task with Confirmation" \
    "$TODO_CMD --delete 1 --yes" \
    "✅ Task deleted successfully!"

  # 4.2 Delete Non-Existent Task
  run_test "Delete Non-Existent Task" \
    "$TODO_CMD --delete 999" \
    "❌ Task ID 999 does not exist."

  ####################################################
  # 5. Marking Tasks as Completed
  ####################################################
  # Add a task to mark as completed
  # drop table
  sqlite3 "$DATABASE" "DROP TABLE tasks;"
  add_output=$($TODO_CMD --add -t 'Task to complete' 2>&1)
  if ! echo "$add_output" | grep -Fq "✅ Task added successfully!"; then
    echo "❌ Failed to add task in test 'Mark a Task as Completed'."
    echo "Actual output:"
    echo "$add_output"
    restore_environment
    exit 1
  fi

  # 5.1 Mark a Task as Completed (Command-Line Mode)
  run_test "Mark a Task as Completed" \
    "$TODO_CMD --complete 1" \
    "✅ Task marked as completed!"

  # 5.2 Mark Non-Existent Task as Completed
  run_test "Mark Non-Existent Task as Completed" \
    "$TODO_CMD --complete 999" \
    "❌ Task ID 999 does not exist."

  ####################################################
  # 6. Handling Recurring Tasks
  ####################################################
  # 6.1 Verify Task Recurrence After Completion
  # Add a recurring task
  sqlite3 "$DATABASE" "DROP TABLE tasks;"
  $TODO_CMD --add -t "Daily Standup" -D "$(date '+%Y-%m-%d')" -r "* * 1-5" --yes >/dev/null
  # Mark it as completed
  run_test "Verify Recurring Task After Completion" \
    "$TODO_CMD --complete 1" \
    "✅ Task marked as completed!"

  # 6.2 Verify End Date Enforcement
  # Add a recurring task with an end date
  sqlite3 "$DATABASE" "DROP TABLE tasks;"
  $TODO_CMD --add -t "Monthly Review" -D "2023-11-01" -e "2023-11-30" -i "30" --yes >/dev/null
  # Get the last inserted ID
  # Mark it as completed multiple times to reach past the end date
  run_test "Verify End Date Enforcement - First Completion" \
    "$TODO_CMD --complete 1" \
    "✅ Task marked as completed!"
  # Try to complete the new task
  new_task_id=$(sqlite3 "$DATABASE" "SELECT id FROM tasks WHERE status = 'pending' AND title = 'Monthly Review';")
  run_test "Verify End Date Enforcement - Second Completion" \
    "$TODO_CMD --complete $new_task_id" \
    "ℹ️ No pending tasks due today or past due date."

  ####################################################
  # 7. Edge Cases and Validations
  ####################################################
  # 7.1 Add Task with Due Date in the Past
  run_test "Add Task with Due Date in the Past" \
    "$TODO_CMD --add -t 'Task with past due date' -D '2000-01-01'" \
    "✅ Task added successfully!"

  # 7.2 Verify Date Validation on Leap Year
  run_test "Add Task on Leap Day of Leap Year" \
    "$TODO_CMD --add -t 'Leap Year Task' -D '2024-02-29'" \
    "✅ Task added successfully!"

  # 7.3 Attempt to Add Task on Invalid Leap Day
  run_test "Add Task on Invalid Leap Day" \
    "$TODO_CMD --add -t 'Invalid Leap Day Task' -D '2023-02-29'" \
    "❌ Invalid due date format. Please use YYYY-MM-DD."

  # 7.4 SQL Injection Attempt in Title
  run_test "SQL Injection Attempt in Title" \
    "$TODO_CMD --add -t \"'); DROP TABLE tasks; --\"" \
    "✅ Task added successfully!"

  # Verify that the tasks table still exists
  run_test "Verify Tasks Table Exists" \
    "sqlite3 $DATABASE '.schema tasks' | grep -F 'CREATE TABLE tasks'" \
    "CREATE TABLE tasks"

  ####################################################
  # 8. Invalid Command-Line Arguments
  ####################################################
  # 8.1 Unknown Command-Line Flag
  run_test "Unknown Command-Line Flag" \
    "$TODO_CMD --unknownflag" \
    "❌ Unknown command: --unknownflag"

  ####################################################
  # Finalize tests
  ####################################################
  echo "All tests passed successfully!"

  # Restore the original environment
  restore_environment
}

# Run the main function
main
