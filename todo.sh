#!/bin/bash

# TODO Application using SQLite and gum
# Updated to add a CHECK constraint on due_date and validate date inputs

DB_ROOT=$XDG_CONFIG_HOME || "$HOME/.config"

DATABASE="${DATABASE:-$DB_ROOT/todo.db}"

if command -v gdate >/dev/null 2>&1; then
    DATE_CMD="gdate"
else
    DATE_CMD="date"
fi

# Load plugin scripts
load_plugins() {
    for plugin in plugins/*.sh; do
        # shellcheck source=/dev/null
        [ -f "$plugin" ] && source "$plugin"
    done
}

# Initialize the database if it doesn't exist, or migrate it if needed
initialize_database() {
    create_database
}

# Function to create the database with the due_date CHECK constraint
create_database() {
    sqlite3 "$DATABASE" <<EOF
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    due_date TEXT CHECK (due_date IS NULL OR due_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
    end_date TEXT CHECK (end_date IS NULL OR end_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
    interval_days INTEGER,
    recurring_expression TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
);
EOF
}

# Function to join array elements with a delimiter
join_by() {
    local IFS="$1"
    shift
    echo "$*"
}

# Function to parse the field and check if the value matches
field_matches() {
    field_expr="$1"
    value="$2"

    # If field_expr is '*', it matches any value
    if [ "$field_expr" = "*" ]; then
        return 0
    fi

    # Split the field expression by commas
    IFS=',' read -ra parts <<<"$field_expr"
    for part in "${parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # It's a range
            start="${BASH_REMATCH[1]}"
            end="${BASH_REMATCH[2]}"
            if ((value >= start && value <= end)); then
                return 0
            fi
        elif [ "$part" -eq "$value" ] 2>/dev/null; then
            # It's an exact value
            if [ "$part" -eq "$value" ]; then
                return 0
            fi
        fi
    done

    # No match found
    return 1
}

# Function to calculate the next date based on a cron-like expression
get_next_date() {
    # Arguments: recurring_expression, start_date
    # Output: next_date (echoed)
    recurring_expression="$1" # Format: <day_of_month> <month> <day_of_week>
    start_date="$2"           # Format: YYYY-MM-DD

    # Parse the recurring expression
    IFS=' ' read -r dom_expr mon_expr dow_expr <<<"$recurring_expression"

    # Start from the day after the start date
    current_date=$($DATE_CMD -I -d "$start_date +1 day")
    # Loop until we find a matching date
    while true; do
        # Get components of the current date
        current_dom=$($DATE_CMD -d "$current_date" '+%d')
        current_mon=$($DATE_CMD -d "$current_date" '+%m')
        current_dow=$($DATE_CMD -d "$current_date" '+%u') # 1=Monday, ..., 7=Sunday

        # Remove leading zeros for comparison
        current_dom="${current_dom#0}"
        current_mon="${current_mon#0}"

        # Initialize match as false
        match=false

        # Check if the current date matches the expression
        if field_matches "$dom_expr" "$current_dom" &&
            field_matches "$mon_expr" "$current_mon" &&
            field_matches "$dow_expr" "$current_dow"; then
            match=true
        fi

        if [ "$match" = true ]; then
            echo "$current_date"
            return 0
        fi

        # Move to the next day
        current_date=$($DATE_CMD -I -d "$current_date +1 day")
    done
}

explain_recurring_expression() {
    recurring_expression="$1"
    interval_days="${2:-}"

    if [ "$recurring_expression" = "none" ] || [ -z "$recurring_expression" ]; then
        if [ -n "$interval_days" ]; then
            echo "Every $interval_days day(s)"
        else
            echo "Does not recur"
        fi
        return
    fi

    # Parse the recurring expression
    IFS=' ' read -r dom_expr mon_expr dow_expr <<<"$recurring_expression"

    # Prepare human-readable parts
    dom_desc=""
    mon_desc=""
    dow_desc=""

    # Validate that dom_expr, mon_expr, dow_expr are valid
    validate_field() {
        field_expr="$1"
        field_type="$2"

        if [ "$field_expr" = "*" ]; then
            return 0
        fi

        IFS=',' read -ra parts <<<"$field_expr"
        for part in "${parts[@]}"; do
            if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                start="${BASH_REMATCH[1]}"
                end="${BASH_REMATCH[2]}"
            elif [[ "$part" =~ ^[0-9]+$ ]]; then
                start="$part"
                end="$part"
            else
                echo "Invalid $field_type value: $part"
                return 1
            fi

            # Validate the numeric range based on field_type
            case "$field_type" in
            dom)
                min=1
                max=31
                ;;
            mon)
                min=1
                max=12
                ;;
            dow)
                min=1
                max=7
                ;;
            esac

            if ((start < min || end > max)); then
                echo "Invalid $field_type range: $start-$end"
                return 1
            fi
        done
        return 0
    }

    # Validate each field
    for field in "dom" "mon" "dow"; do
        field_expr_var="${field}_expr"
        if ! validate_field "${!field_expr_var}" "$field"; then
            echo "Invalid recurring expression."
            return
        fi
    done

    # Helper function to interpret field expressions
    interpret_field() {
        field_expr="$1"
        field_type="$2" # 'dom', 'mon', or 'dow'

        if [ "$field_expr" = "*" ]; then
            echo ""
        else
            # Handle lists and ranges
            values=()
            IFS=',' read -ra parts <<<"$field_expr"
            for part in "${parts[@]}"; do
                if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    # Range
                    start="${BASH_REMATCH[1]}"
                    end="${BASH_REMATCH[2]}"

                    if [ "$field_type" = "dow" ]; then
                        start_day=$(get_day_name "$start")
                        end_day=$(get_day_name "$end")
                        values+=("from $start_day to $end_day")
                    elif [ "$field_type" = "mon" ]; then
                        start_month=$(get_month_name "$start")
                        end_month=$(get_month_name "$end")
                        values+=("from $start_month to $end_month")
                    else
                        values+=("from $start to $end")
                    fi
                else
                    # Single value
                    if [ "$field_type" = "dow" ]; then
                        day_name=$(get_day_name "$part")
                        values+=("$day_name")
                    elif [ "$field_type" = "mon" ]; then
                        month_name=$(get_month_name "$part")
                        values+=("$month_name")
                    else
                        values+=("$part")
                    fi
                fi
            done

            # Combine values into a description
            if [ "$field_type" = "dow" ]; then
                echo "on $(join_by ', ' "${values[@]}")"
            elif [ "$field_type" = "mon" ]; then
                echo "in $(join_by ', ' "${values[@]}")"
            else
                echo "on day $(join_by ', ' "${values[@]}")"
            fi
        fi
    }

    # Function to get day name from number
    get_day_name() {
        case "$1" in
        1) echo "Monday" ;;
        2) echo "Tuesday" ;;
        3) echo "Wednesday" ;;
        4) echo "Thursday" ;;
        5) echo "Friday" ;;
        6) echo "Saturday" ;;
        7) echo "Sunday" ;;
        *) echo "Invalid" ;;
        esac
    }

    # Function to get month name from number
    get_month_name() {
        case "$1" in
        1) echo "January" ;;
        2) echo "February" ;;
        3) echo "March" ;;
        4) echo "April" ;;
        5) echo "May" ;;
        6) echo "June" ;;
        7) echo "July" ;;
        8) echo "August" ;;
        9) echo "September" ;;
        10) echo "October" ;;
        11) echo "November" ;;
        12) echo "December" ;;
        *) echo "Invalid" ;;
        esac
    }

    # Interpret each field
    dom_desc=$(interpret_field "$dom_expr" "dom")
    mon_desc=$(interpret_field "$mon_expr" "mon")
    dow_desc=$(interpret_field "$dow_expr" "dow")

    # Build the final description
    description="Every"

    if [ -n "$dow_desc" ]; then
        description="$description $dow_desc"
    fi

    if [ -n "$dom_desc" ]; then
        [ -n "$dow_desc" ] && description="$description and"
        description="$description $dom_desc"
    fi

    if [ -n "$mon_desc" ]; then
        description="$description $mon_desc"
    fi

    echo "$description"
}

validate_recurring_expression() {
    recurring_expression="$1"

    if [ "$recurring_expression" = "none" ] || [ -z "$recurring_expression" ]; then
        return 0 # Valid
    fi

    IFS=' ' read -r dom_expr mon_expr dow_expr <<<"$recurring_expression"

    # Check if we have exactly three fields
    if [ -z "$dom_expr" ] || [ -z "$mon_expr" ] || [ -z "$dow_expr" ]; then
        return 1 # Invalid
    fi

    # Function to validate a field
    validate_field() {
        field_expr="$1"
        field_type="$2"

        if [ "$field_expr" = "*" ]; then
            return 0 # Valid wildcard
        fi

        # Split by commas
        IFS=',' read -ra parts <<<"$field_expr"
        for part in "${parts[@]}"; do
            # Check for range or single number
            if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                start="${BASH_REMATCH[1]}"
                end="${BASH_REMATCH[2]}"
            elif [[ "$part" =~ ^[0-9]+$ ]]; then
                start="$part"
                end="$part"
            else
                return 1 # Invalid format
            fi

            # Validate the numbers based on the field type
            case "$field_type" in
            dom)
                min=1
                max=31
                ;;
            mon)
                min=1
                max=12
                ;;
            dow)
                min=1
                max=7
                ;;
            *) return 1 ;;
            esac

            if ((start < min || start > max || end < min || end > max)); then
                return 1 # Out of range
            fi
        done

        return 0 # Field is valid
    }

    # Validate each field
    if ! validate_field "$dom_expr" "dom"; then
        return 1
    fi
    if ! validate_field "$mon_expr" "mon"; then
        return 1
    fi
    if ! validate_field "$dow_expr" "dow"; then
        return 1
    fi

    return 0 # Expression is valid
}

# Add a new task
add_task() {
    # Parse arguments or prompt user input
    if [ "$#" -gt 0 ]; then
        # Existing argument parsing code
        while [[ "$#" -gt 0 ]]; do
            case $1 in
            -t | --title)
                title="$2"
                shift
                ;;
            -d | --description)
                description="$2"
                shift
                ;;
            -D | --due-date)
                due_date="$2"
                shift
                ;;
            -e | --end-date)
                end_date="$2"
                shift
                ;;
            -r | --recurring)
                recurring_expression="$2"
                shift
                ;;
            -i | --interval-days)
                interval_days="$2"
                shift
                ;;
            -y | --yes)
                confirm="true"
                ;;

            *)
                echo "❌ Unknown parameter passed: $1"
                return 1
                ;;
            esac
            shift
        done
    else
        # Interactive prompts
        title=$(gum input --placeholder "Enter task title ✍️")
        [ -z "$title" ] && return
        description=$(gum input --placeholder "Enter task description 📝")
        due_date=$(gum input --placeholder "Enter due date (YYYY-MM-DD) 📅")
        end_date=$(gum input --placeholder "Enter end date (YYYY-MM-DD), if any 🏁")
        recurring_type=$(gum choose "No recurrence" "Cron-like expression" "Interval in days" --header "Select the new recurrence type:")
        if [ "$recurring_type" = "Cron-like expression" ]; then
            recurring_expression=$(gum input --placeholder "Enter new recurring expression (e.g., '1-5 * *')  ")
            interval_days=""
        elif [ "$recurring_type" = "Interval in days" ]; then
            interval_days=$(gum input --placeholder "Enter new interval in days (e.g., '14' for every 14 days)")
            recurring_expression="none"
        else
            recurring_expression="none"
            interval_days=""
        fi
    fi

    # Validate inputs
    if [ -n "$title" ]; then
        title=$(echo "$title" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [ -z "$title" ]; then
            gum style --foreground 1 "❌ Title cannot be empty."
            return
        fi
    fi

    if [ -z "$recurring_expression" ]; then
        recurring_expression="none"
    fi

    # if due date is not provided, set it to today
    if [ -z "$due_date" ]; then
        due_date=$($DATE_CMD '+%Y-%m-%d')
    fi

    # Validate due_date format
    if [ -n "$due_date" ]; then
        if ! [[ "$due_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            gum style --foreground 1 "❌ Invalid date format. Please use YYYY-MM-DD."
            return
        fi
        if ! $DATE_CMD -d "$due_date" '+%Y-%m-%d' >/dev/null 2>&1; then
            gum style --foreground 1 "❌ Invalid date. Please enter a valid date."
            return
        fi
    fi

    # Validate end_date format
    if [ -n "$end_date" ]; then
        if ! [[ "$end_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            gum style --foreground 1 "❌ Invalid end date format. Please use YYYY-MM-DD."
            return
        fi
        if ! $DATE_CMD -d "$end_date" '+%Y-%m-%d' >/dev/null 2>&1; then
            gum style --foreground 1 "❌ Invalid end date. Please enter a valid date."
            return
        fi
    fi

    # Check if end_date is after due_date
    if [ -n "$due_date" ] && [ -n "$end_date" ]; then
        if [[ "$($DATE_CMD -d "$end_date" '+%s')" -lt "$($DATE_CMD -d "$due_date" '+%s')" ]]; then
            gum style --foreground 1 "❌ End date cannot be before due date."
            return
        fi
    fi

    # Validate and confirm recurrence
    if [ -n "$interval_days" ]; then
        if ! [[ "$interval_days" =~ ^[0-9]+$ ]] || [ "$interval_days" -le 0 ]; then
            gum style --foreground 1 "❌ Interval days must be a positive integer."
            return
        fi
        human_readable_recurrence="Every $interval_days day(s)"
        if [ "$confirm" != "true" ] && ! gum confirm "The task is set to recur: $human_readable_recurrence. Is this correct?"; then
            gum style --foreground 3 "❌ Task not added. Please try again with the correct interval."
            return
        fi
    elif [ "$recurring_expression" != "none" ]; then
        # Validate the recurring expression
        if ! validate_recurring_expression "$recurring_expression"; then
            gum style --foreground 1 "❌ Invalid recurring expression."
            return
        fi

        human_readable_recurrence=$(explain_recurring_expression "$recurring_expression")
        if [ "$confirm" != "true" ] && ! gum confirm "The task is set to recur: $human_readable_recurrence. Is this correct?"; then
            gum style --foreground 3 "❌ Task not added. Please try again with the correct recurrence."
            return
        fi
    else
        recurring_expression="none"
    fi

    # Escape single quotes in inputs
    [ -n "$title" ] && title="${title//\'/\'\'}"
    [ -n "$description" ] && description="${description//\'/\'\'}"
    [ -n "$due_date" ] && due_date="${due_date//\'/\'\'}"
    [ -n "$end_date" ] && end_date="${end_date//\'/\'\'}"
    [ -n "$recurring_expression" ] && recurring_expression="${recurring_expression//\'/\'\'}"
    [ -n "$interval_days" ] && interval_days="${interval_days//\'/\'\'}"

    # Prepare due_date_value and end_date_value
    [ -n "$due_date" ] && due_date_value="'$due_date'"
    [ -z "$due_date" ] && due_date_value="NULL"

    [ -n "$end_date" ] && end_date_value="'$end_date'"
    [ -z "$end_date" ] && end_date_value="NULL"

    # Insert into database
    sqlite3 "$DATABASE" <<EOF
INSERT INTO tasks (title, description, due_date, end_date, recurring_expression, interval_days, status)
VALUES ('$title', '$description', $due_date_value, $end_date_value, '$recurring_expression', ${interval_days:-NULL}, 'pending');
EOF

    list_tasks pending
    gum style --foreground 212 "✅ Task added successfully!"
}

# List tasks
list_tasks() {
    # Ensure DATABASE is defined
    if [ -z "$DATABASE" ]; then
        echo "❌ DATABASE variable is not set."
        return 1
    fi

    # If no status is provided, prompt the user to choose
    if [ -z "$1" ]; then
        # Use gum choose to let the user select the status
        filter_status=$(gum choose "today" "pending" "completed" "archived" "all" --header "Select tasks to list:")
    else
        filter_status="$1"
    fi

    # Validate filter_status and set the SQL condition
    case "$filter_status" in
    pending | completed | archived)
        status_condition="status = '$filter_status' AND"
        ;;
    all)
        status_condition=""
        ;;
    today)
        status_condition="(due_date = date('now') AND status = 'completed') OR status = 'pending' AND"
        ;;
    *)
        gum style --foreground 1 "❌ Invalid status. Please choose pending, completed, archived, or all."
        return
        ;;
    esac

    # Query the tasks based on the filter_status
    tasks=$(sqlite3 -separator $'\t' "$DATABASE" "
    SELECT id, title, status, due_date, recurring_expression, interval_days 
    FROM tasks 
    WHERE $status_condition 1=1 
        AND (due_date <= date('now'))
    ORDER BY status;")

    if [ -z "$tasks" ]; then
        gum style --foreground 1 "ℹ️ No tasks found."
        return
    fi

    # Ensure the explain_recurring_expression function is defined
    if ! declare -f explain_recurring_expression >/dev/null; then
        gum style --foreground 1 "❌ The function 'explain_recurring_expression' is not defined."
        return
    fi

    # Initialize an array to hold formatted task entries
    formatted_tasks=()

    # Read tasks line by line
    while IFS=$'\t' read -r id title status due_date recurring_expression interval_days; do
        # Assign status icon based on status
        case "$status" in
        pending) status_icon="\033[38;2;200;0;0m\033[0m" ;;
        completed) status_icon="\033[38;2;0;200;0m󰄲\033[0m" ;;
        archived) status_icon="󰏗" ;;
        *) status_icon="" ;;
        esac

        # Determine human-readable recurrence
        if [ -n "$interval_days" ] && [ "$interval_days" -ne 0 ]; then
            human_readable_recurrence="Every $interval_days day(s)"
        elif [ "$recurring_expression" != "none" ] && [ -n "$recurring_expression" ]; then
            human_readable_recurrence=$(explain_recurring_expression "$recurring_expression")
        else
            human_readable_recurrence="—"
        fi

        # Combine recurrence info with icon if applicable
        if [ "$human_readable_recurrence" != "—" ]; then
            recurrence_info=" $human_readable_recurrence"
        else
            recurrence_info="$human_readable_recurrence"
        fi

        # Append the formatted entry to the array
        # Each entry is a single string with fields separated by tabs
        formatted_tasks+=("$status_icon|$id|$title|$recurrence_info|$due_date")
    done <<<"$tasks"

    # Prepare the header and combine with formatted tasks
    header="|ID|Title|Recurrence|Due Date"
    table_content=$(printf "%s\n" "${formatted_tasks[@]}")

    # Display tasks using gum table
    echo -e "$header\n$table_content" | gum table --border normal --header.foreground 2 --print -s "|"
}

show_task_detail() {
    id="$1"

    if [ -z "$id" ]; then
        id=$(gum input --placeholder "Enter task ID to show details 📋")
        [ -z "$id" ] && return
    fi

    task=$(sqlite3 -separator $'\t' "$DATABASE" "
    SELECT id, title, status, due_date, end_date, description, recurring_expression, interval_days
    FROM tasks 
    WHERE id = $id;")

    if [ -z "$task" ]; then
        gum style --foreground 1 "❌ Task ID $id does not exist."
        return
    fi

    IFS=$'\t' read -r id title status due_date end_date description recurring_expression interval_days <<<"$task"

    # Determine human-readable status
    case "$status" in
    pending) status_text="Pending" ;;
    completed) status_text="Completed" ;;
    archived) status_text="Archived" ;;
    *) status_text="Unknown" ;;
    esac

    # Determine human-readable recurrence
    if [ -n "$interval_days" ]; then
        human_readable_recurrence="Every $interval_days day(s)"
    elif [ "$recurring_expression" != "none" ] && [ -n "$recurring_expression" ]; then
        human_readable_recurrence=$(explain_recurring_expression "$recurring_expression")
    else
        human_readable_recurrence="—"
    fi

    # Prepare the task details
    echo "ID: $id"
    echo "Title: $title"
    [ -n "$description" ] && echo "Description: $description"
    echo "Status: $status_text"
    echo "Due Date: $due_date"
    [ -n "$end_date" ] && echo "End Date: $end_date"
    [ "$human_readable_recurrence" != "—" ] && echo "Recurrence: $human_readable_recurrence"
    [ -n "$interval_days" ] && echo "Interval in Days: $interval_days"
}

# Update a task
update_task() {
    id="$1"
    shift

    if [ -z "$id" ]; then
        id=$(gum input --placeholder "Enter task ID to update ✏️")
        [ -z "$id" ] && return
    fi

    existing=$(sqlite3 "$DATABASE" "SELECT id FROM tasks WHERE id = $id;")
    if [ -z "$existing" ]; then
        gum style --foreground 1 "❌ Task ID $id does not exist."
        return
    fi

    # Parse arguments or prompt user input
    if [ "$#" -gt 0 ]; then
        while [[ "$#" -gt 0 ]]; do
            case $1 in
            -t | --title)
                title="$2"
                shift
                ;;
            -d | --description)
                description="$2"
                shift
                ;;
            -D | --due-date)
                due_date="$2"
                shift
                ;;
            -e | --end-date)
                end_date="$2"
                shift
                ;;
            -r | --recurring)
                recurring_expression="$2"
                shift
                ;;
            -i | --interval-days)
                interval_days="$2"
                shift
                ;;
            *)
                echo "❌ Unknown parameter passed: $1"
                return 1
                ;;
            esac
            shift
        done
    else
        # Interactive prompts
        title=$(gum input --placeholder "Enter new task title ✍️")
        description=$(gum input --placeholder "Enter new task description 📝")
        due_date=$(gum input --placeholder "Enter new due date (YYYY-MM-DD) 📅")
        end_date=$(gum input --placeholder "Enter new end date (YYYY-MM-DD), if any 🏁")
        recurring_type=$(gum choose "No recurrence" "Cron-like expression" "Interval in days" --header "Select the new recurrence type:")
        if [ "$recurring_type" = "Cron-like expression" ]; then
            recurring_expression=$(gum input --placeholder "Enter new recurring expression (e.g., '1-5 * *')  ")
            interval_days=""
        elif [ "$recurring_type" = "Interval in days" ]; then
            interval_days=$(gum input --placeholder "Enter new interval in days (e.g., '14' for every 14 days)")
            recurring_expression="none"
        else
            recurring_expression="none"
            interval_days=""
        fi
    fi

    # Validate inputs
    if [ -n "$title" ]; then
        title=$(echo "$title" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        if [ -z "$title" ]; then
            gum style --foreground 1 "❌ Title cannot be empty."
            return
        fi
    fi

    # Validate due_date format
    if [ -n "$due_date" ]; then
        if ! [[ "$due_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            gum style --foreground 1 "❌ Invalid date format. Please use YYYY-MM-DD."
            return
        fi
        if ! $DATE_CMD -d "$due_date" '+%Y-%m-%d' >/dev/null 2>&1; then
            gum style --foreground 1 "❌ Invalid date. Please enter a valid date."
            return
        fi
    fi

    # Validate end_date format
    if [ -n "$end_date" ]; then
        if ! [[ "$end_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            gum style --foreground 1 "❌ Invalid end date format. Please use YYYY-MM-DD."
            return
        fi
        if ! $DATE_CMD -d "$end_date" '+%Y-%m-%d' >/dev/null 2>&1; then
            gum style --foreground 1 "❌ Invalid end date. Please enter a valid date."
            return
        fi
    fi

    # Validate recurring_expression and interval_days
    if [ -n "$recurring_expression" ] && [ -n "$interval_days" ]; then
        gum style --foreground 1 "❌ Cannot specify both a recurring expression and an interval in days."
        return
    fi

    if [ -n "$recurring_expression" ] && [ "$recurring_expression" != "none" ]; then
        if ! validate_recurring_expression "$recurring_expression"; then
            gum style --foreground 1 "❌ Invalid recurring expression."
            return
        fi
    fi

    if [ -n "$interval_days" ]; then
        if ! [[ "$interval_days" =~ ^[0-9]+$ ]] || [ "$interval_days" -le 0 ]; then
            gum style --foreground 1 "❌ Interval days must be a positive integer."
            return
        fi
    fi

    # Escape single quotes in inputs
    [ -n "$title" ] && title="${title//\'/\'\'}"
    [ -n "$description" ] && description="${description//\'/\'\'}"
    [ -n "$due_date" ] && due_date="${due_date//\'/\'\'}"
    [ -n "$end_date" ] && end_date="${end_date//\'/\'\'}"
    [ -n "$recurring_expression" ] && recurring_expression="${recurring_expression//\'/\'\'}"
    [ -n "$interval_days" ] && interval_days="${interval_days//\'/\'\'}"

    # Prepare due_date_value and end_date_value
    [ -n "$due_date" ] && due_date_value="'$due_date'"
    [ -z "$due_date" ] && due_date_value="NULL"

    [ -n "$end_date" ] && end_date_value="'$end_date'"
    [ -z "$end_date" ] && end_date_value="NULL"

    # Build update query
    update_fields=()
    [ -n "$title" ] && update_fields+=("title = '$title'")
    [ -n "$description" ] && update_fields+=("description = '$description'")
    [ -n "$due_date" ] && update_fields+=("due_date = $due_date_value")
    [ -n "$end_date" ] && update_fields+=("end_date = $end_date_value")
    [ -n "$recurring_expression" ] && update_fields+=("recurring_expression = '$recurring_expression'")
    if [ -n "$interval_days" ]; then
        update_fields+=("interval_days = $interval_days")
    elif [ "$interval_days" = "" ]; then
        # User wants to unset interval_days
        update_fields+=("interval_days = NULL")
    fi

    if [ "${#update_fields[@]}" -eq 0 ]; then
        gum style --foreground 3 "ℹ️ No fields to update."
        return
    fi

    update_query="UPDATE tasks SET $(join_by ', ' "${update_fields[@]}") WHERE id = $id;"

    sqlite3 "$DATABASE" "$update_query"

    gum style --foreground 212 "✅ Task updated successfully!"
}

# Delete a task
delete_task() {
    id="$1"

    if [ -z "$id" ]; then
        id=$(gum input --placeholder "Enter task ID to delete 🗑️")
        [ -z "$id" ] && return
    fi

    existing=$(sqlite3 "$DATABASE" "SELECT id FROM tasks WHERE id = $id;")
    if [ -z "$existing" ]; then
        gum style --foreground 1 "❌ Task ID $id does not exist."
        return
    fi

    if [ "$2" == "--yes" ]; then
        confirm="true"
    else
        gum confirm "🗑️ Are you sure you want to delete task ID $id?" && confirm="true"
    fi

    if [ "$confirm" == "true" ]; then
        sqlite3 "$DATABASE" "DELETE FROM tasks WHERE id = $id;"
        gum style --foreground 212 "✅ Task deleted successfully!"
    else
        gum style --foreground 3 "❌ Deletion cancelled."
    fi
}

# Mark a task as completed
mark_task_completed() {
    id="$1"
    shift

    if [ -z "$id" ]; then
        # Interactive mode: Use gum choose to select from the list of tasks
        # Get current date in YYYY-MM-DD format
        current_date=$($DATE_CMD '+%Y-%m-%d')

        # Retrieve pending tasks due today or past due date
        tasks=$(sqlite3 -separator $'\t' "$DATABASE" "SELECT id, title, due_date FROM tasks WHERE status = 'pending' AND due_date <= '$current_date';")

        if [ -z "$tasks" ]; then
            gum style --foreground 1 "ℹ️ No pending tasks due today or past due date."
            return
        fi

        # Prepare options for gum choose
        options=()
        while IFS=$'\t' read -r tid title due_date; do
            options+=("[$tid] $title 📅 Due: $due_date")
        done <<<"$tasks"

        # Use gum choose to select tasks to mark as completed
        selected_task=$(printf "%s\n" "${options[@]}" | gum choose --no-limit --header "Select task(s) to mark as completed:")
        if [ -z "$selected_task" ]; then
            gum style --foreground 3 "❌ No task selected. Operation cancelled."
            return
        fi

        # Extract IDs from selected tasks
        ids=()
        while read -r line; do
            tid=$(echo "$line" | awk -F']' '{print $1}' | tr -d '[')
            ids+=("$tid")
        done <<<"$selected_task"

        # Mark each selected task as completed
        for id in "${ids[@]}"; do
            existing=$(sqlite3 "$DATABASE" "SELECT id FROM tasks WHERE id = $id;")
            if [ -z "$existing" ]; then
                gum style --foreground 1 "❌ Task ID $id does not exist."
                continue
            fi

            sqlite3 "$DATABASE" "UPDATE tasks SET status = 'completed' WHERE id = $id;"
            gum style --foreground 212 "✅ Task ID $id marked as completed!"
        done

        # Handle recurrence after marking tasks as completed
        handle_recurring_tasks

    else
        # Non-interactive mode: Use provided ID
        existing=$(sqlite3 "$DATABASE" "SELECT id FROM tasks WHERE id = $id;")
        if [ -z "$existing" ]; then
            gum style --foreground 1 "❌ Task ID $id does not exist."
            return
        fi

        sqlite3 "$DATABASE" "UPDATE tasks SET status = 'completed' WHERE id = $id;"
        gum style --foreground 212 "✅ Task marked as completed!"

        # Handle recurrence immediately
        handle_recurring_tasks
    fi
}

# Handle recurring tasks
handle_recurring_tasks() {
    tasks=$(sqlite3 -separator $'\t' "$DATABASE" "SELECT id, title, description, due_date, end_date, recurring_expression, interval_days FROM tasks WHERE status = 'completed' AND (recurring_expression != 'none' OR interval_days IS NOT NULL);")

    [ -z "$tasks" ] && return

    # Start the spinner
    gum spin --spinner dot --title "Processing recurring tasks..." -- bash -c "
    echo \"\$tasks\" | while IFS=\$'\t' read -r id title description due_date end_date recurring_expression interval_days; do
        # Determine next_due_date based on recurrence
        if [ -n \"\$interval_days\" ]; then
            next_due_date=\$($DATE_CMD -I -d \"\$due_date +\$interval_days day\")
        elif [ \"\$recurring_expression\" != \"none\" ] && [ -n \"\$recurring_expression\" ]; then
            next_due_date=\$(get_next_date \"\$recurring_expression\" \"\$due_date\")
        else
            continue
        fi

        if [ -z \"\$next_due_date\" ]; then
            echo \"❌ Error calculating next due date for task ID \$id.\"
            continue
        fi

        # Check if next_due_date exceeds end_date
        if [ -n \"\$end_date\" ]; then
            if [[ \"\$($DATE_CMD -d \"\$next_due_date\" '+%s')\" -gt \"\$($DATE_CMD -d \"\$end_date\" '+%s')\" ]]; then
                # Do not create a new task, as it's past the end date
                sqlite3 \"$DATABASE\" \"UPDATE tasks SET status = 'archived' WHERE id = \$id;\"
                echo \"⏹️ Task ID \$id has reached its end date and will not recur further.\"
                continue
            fi
        fi

        # Sanitize inputs
        title=\$(echo \"\$title\" | sed \"s/'/''/g\")
        description=\$(echo \"\$description\" | sed \"s/'/''/g\")
        next_due_date=\$(echo \"\$next_due_date\" | sed \"s/'/''/g\")
        end_date=\$(echo \"\$end_date\" | sed \"s/'/''/g\")
        recurring_expression=\$(echo \"\$recurring_expression\" | sed \"s/'/''/g\")
        interval_days=\$(echo \"\$interval_days\" | sed \"s/'/''/g\")

        # Insert new task
        sqlite3 \"$DATABASE\" <<SQL
INSERT INTO tasks (title, description, due_date, end_date, recurring_expression, interval_days, status)
VALUES ('\$title', '\$description', '\$next_due_date', '\$end_date', '\$recurring_expression', '\$interval_days', 'pending');
SQL

        # Archive the original task
        sqlite3 \"$DATABASE\" \"UPDATE tasks SET status = 'archived' WHERE id = \$id;\"
    done
    " | while read -r line; do
        gum style --foreground 3 "\$line"
    done

    gum style --foreground 212 "✅ Recurring tasks processed."
}

# Show usage
show_help() {
    echo "📖 Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --add                ➕ Add a new task"
    echo "    -t, --title            Task title"
    echo "    -d, --description      Task description"
    echo "    -D, --due-date         Due date (YYYY-MM-DD)"
    echo "    -r, --recurring        Recurring expression (e.g., '1-5 * *', '* 6-8 *', '* * 1,3,5')"
    echo
    echo "  --list [status]      📋 List tasks (status can be pending, completed, archived or all)"
    echo
    echo "  --update <ID>        ✏️ Update a task"
    echo "    -t, --title            New task title"
    echo "    -d, --description      New task description"
    echo "    -D, --due-date         New due date (YYYY-MM-DD)"
    echo "    -r, --recurring        New recurring expression"
    echo
    echo "  --delete <ID>        🗑️ Delete a task"
    echo "      --yes                Confirm deletion without prompting"
    echo
    echo "  --complete <ID>      ✅ Mark a task as completed"
    echo
    echo "  --help               ℹ️ Show this help message"

    # List plugin commands
    echo "Plugin Commands:"
    for plugin in plugins/*.sh; do
        [ -f "$plugin" ] || continue
        plugin_name="$(basename "$plugin" .sh)"
        if type "plugin_help_$plugin_name" >/dev/null 2>&1; then
            "plugin_help_$plugin_name"
        fi
    done
    echo
    echo "If no options are provided, the script will run in interactive mode."
}

nuke_database() {
    gum confirm "🚨 Are you sure you want to delete all tasks? This action cannot be undone." && confirm="true"
    if [ "$confirm" == "true" ]; then
        sqlite3 "$DATABASE" "DROP TABLE IF EXISTS tasks;"
        initialize_database
        gum style --foreground 212 "✅ All tasks deleted successfully!"
    else
        gum style --foreground 3 "❌ Deletion cancelled."
    fi
}

main() {
    initialize_database
    load_plugins

    if [ "$#" -eq 0 ]; then
        main_menu
    else
        subcommand="$1"
        shift

        # Check if the subcommand is a built-in command
        case "$subcommand" in
        --add)
            add_task "$@"
            ;;
        --list)
            list_tasks "$@"
            ;;
        --detail)
            show_task_detail "$@"
            ;;
        --update)
            update_task "$@"
            ;;
        --delete)
            delete_task "$@"
            ;;
        --complete)
            mark_task_completed "$@"
            ;;
        --help)
            show_help
            ;;
        --nuke)
            nuke_database
            ;;
        *)
            # If not a built-in command, check for plugin commands
            if type "plugin_${subcommand}" >/dev/null 2>&1; then
                "plugin_${subcommand}" "$@"
            else
                echo "❌ Unknown command: $subcommand"
                show_help
                exit 1
            fi
            ;;
        esac
    fi
}

# Main menu for interactive mode
main_menu() {
    while true; do
        choice=$(gum choose "➕ Add a task" "📋 List tasks" "✏️ Update a task" "🗑️ Delete a task" "✅ Mark task as completed" "🚪 Exit" --header "📌 Select an option:")
        case "$choice" in
        "➕ Add a task")
            add_task
            ;;
        "📋 List tasks")
            list_tasks
            ;;
        "✏️ Update a task")
            update_task
            ;;
        "🗑️ Delete a task")
            delete_task
            ;;
        "✅ Mark task as completed")
            mark_task_completed
            ;;
        "🚪 Exit")
            gum style --foreground 212 "👋 Goodbye!"
            exit 0
            ;;
        esac
    done
}

# Run the application
main "$@"
