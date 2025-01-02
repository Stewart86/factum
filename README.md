# 🎯 Factum

![image](./logo.webp)

> Factum: The Art of Getting Things Done.
>
> -- ChatGPT 4o mini

**❗️❗️NOTE: This application is generated entirely by ChatGPT models including this readme, the logo, the actual bash script and the test script. I am just the "navigator" of this pair programming project wherea, ChatGPT is the "driver". Everything is tested and before publishing this repository. The entire project with multiple prompting and asking ChatGPT for correction took about a morning of work. If you have any questions, do raise it in issue.**

Boost your productivity with our interactive command-line **FACTUM**! 📝✨

Crafted with love using **Bash**, powered by **SQLite** for reliable data storage, and beautifully enhanced with [**gum**](https://github.com/charmbracelet/gum) to provide a delightful and visually appealing user experience. 🎉

**Why You'll Love It:**

- ✅ **Effortless Task Management**: Create, read, update, and delete tasks with ease.
- 🔄 **Powerful Recurring Tasks**: Schedule tasks to recur using flexible cron-like expressions.
- 🏁 **Smart End Dates**: Set end dates for recurring tasks to automatically stop them when you want.
- 📦 **Extensible with Plugins**: Customize and enhance functionality with an easy-to-use plugin system.
- 💎 **Interactive & Intuitive Interface**: Enjoy a user-friendly interface with interactive menus and prompts.
- ⚡ **Command-Line Convenience**: Use command-line arguments for quick and efficient task management.
- 🎨 **Visually Engaging**: Emojis and stylish prompts make managing tasks fun!

Join the community of productivity enthusiasts and take control of your tasks like never before! 🚀

---

## 📜 Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
  - [Interactive Mode](#interactive-mode)
  - [Command-Line Mode](#command-line-mode)
- [Features](#features)
  - [Adding Tasks](#adding-tasks)
  - [Listing Tasks](#listing-tasks)
  - [Updating Tasks](#updating-tasks)
  - [Deleting Tasks](#deleting-tasks)
  - [Marking Tasks as Completed](#marking-tasks-as-completed)
- [Plugins](#plugins)
  - [Plugin System Overview](#plugin-system-overview)
  - [Example Plugin: iCal Import](#example-plugin-ical-import)
    - [Limitations](#limitations)
- [Recurring Expressions](#recurring-expressions)
  - [Syntax](#syntax)
  - [Examples](#examples)
  - [Explanation Function](#explanation-function)
- [Examples](#examples-1)
  - [Adding a Task with Recurrence](#adding-a-task-with-recurrence)
  - [Listing Tasks with Recurrence](#listing-tasks-with-recurrence)
- [Known Issues and Limitations](#known-issues-and-limitations)
- [License](#license)

---

## 🛠️ Prerequisites

- **Bash**: The script is written for Bash. Ensure that you have Bash installed (`v4.0` or higher recommended).
- **SQLite**: Used for persistent storage.

  - Install using:

    ```bash
    # Debian/Ubuntu
    sudo apt-get install sqlite3

    # macOS (if not already installed)
    brew install sqlite
    ```

- **gum**: Enhances the user interface with interactive and stylish prompts.

  - Install using:

    ```bash
    # macOS and Linux (with Homebrew)
    brew install gum

    # Alternatively, download from the GitHub releases:
    # Visit https://github.com/charmbracelet/gum/releases
    ```

- **GNU Coreutils (for macOS users)**: The script relies on GNU `date`.
  - Install using:
    ```bash
    brew install coreutils
    ```
  - The script automatically detects `gdate` and uses it if available.

---

## 🚀 Installation

1. **Clone this repository**

   ```bash
   git clone https://github.com/stewart86/factum.git
   ```

2. **Make the install Script Executable**

   ```bash
   chmod +x install.sh
   ```

3. **Run the install script**

   ```bash
   ./install.sh
   ```

   This script will also verify that `sqlite3`, `gum`, and GNU `date` (if on macOS) are installed and accessible.

---

## 🎮 Usage

You can use the application in two modes:

- **Interactive Mode**: Run the script without arguments to use the interactive menu.
- **Command-Line Mode**: Use command-line arguments for quick, non-interactive operations.

### 🌟 Interactive Mode

Run the script without any arguments:

```bash
./todo.sh
```

You'll be greeted with a vibrant menu:

```
📌 Select an option:
> ➕ Add a task
  📋 List tasks
  ✏️ Update a task
  🗑️ Delete a task
  ✅ Mark task as completed
  🚪 Exit
```

Navigate using the arrow keys and select an option by pressing `Enter`.

### ⚡ Command-Line Mode

Perform actions directly by providing command-line arguments.

**Usage:**

```bash
./todo.sh [options]
```

**Options:**

- `--add` : Add a new task
  - `-t`, `--title` : Task title
  - `-d`, `--description` : Task description
  - `-D`, `--due-date` : Due date (`YYYY-MM-DD`)
  - `-e`, `--end-date` : End date (`YYYY-MM-DD`) for recurring tasks
  - `-r`, `--recurring` : Recurring expression (cron-like format)
- `--list [status]` : List tasks
  - `status` can be `pending`, `completed`, `archived`, or `all`
- `--update <ID>` : Update a task
  - Use the same options as `--add` to specify fields to update
- `--delete <ID> [--yes]` : Delete a task
  - `--yes` : Confirm deletion without prompting
- `--complete <ID>` : Mark a task as completed
- `--help` : Show the help message
- **Plugin Commands**: See [Plugins](#plugins) section for additional commands provided by plugins.

---

## ✨ Features

### ➕ Adding Tasks

Add tasks effortlessly, either interactively or via the command line.

**Interactive Mode:**

1. Select `➕ Add a task`.
2. Follow the prompts to enter:
   - **Title** ✍️
   - **Description** 📝
   - **Due Date** 📅
   - **End Date** 🏁 (for recurring tasks)
   - **Recurring Expression** 🔄

**Command-Line Mode:**

```bash
./todo.sh --add -t "Task Title" -d "Task Description" -D "2023-10-31" -e "2023-12-31" -r "* * 1-5"
```

- The script validates dates and recurring expressions.
- For recurring tasks, a friendly explanation of the recurrence is provided for confirmation.

### 📋 Listing Tasks

Stay on top of your tasks by listing them conveniently.

**Interactive Mode:**

1. Select `📋 List tasks`.
2. Choose the status of tasks to list:
   - `pending`
   - `completed`
   - `archived`
   - `all`

**Command-Line Mode:**

```bash
# List pending tasks
./todo.sh --list pending

# List all tasks
./todo.sh --list all
```

- Tasks are displayed with ID, title, due date, status, and recurrence information.

### ✏️ Updating Tasks

Keep your tasks up to date with ease.

**Interactive Mode:**

1. Select `✏️ Update a task`.
2. Enter the task ID and provide new values for the fields you want to update.

**Command-Line Mode:**

```bash
./todo.sh --update 1 -t "Updated Title" -D "2023-11-15"
```

### 🗑️ Deleting Tasks

Clean up your task list by deleting tasks you no longer need.

**Interactive Mode:**

1. Select `🗑️ Delete a task`.
2. Enter the task ID to delete.
3. Confirm the deletion when prompted.

**Command-Line Mode:**

```bash
./todo.sh --delete 1 --yes
```

- Use `--yes` to bypass the confirmation prompt.

### ✅ Marking Tasks as Completed

Celebrate progress by marking tasks as completed! 🎉

**Interactive Mode:**

1. Select `✅ Mark task as completed`.
2. Select one or more tasks from the list presented.

**Command-Line Mode:**

```bash
./todo.sh --complete 1
```

- If the task is recurring and has an end date, the script will handle recurrence accordingly.

---

## 🔌 Plugins

### 🔧 Plugin System Overview

The TODO application supports a plugin system that allows you to extend its functionality without modifying the core script. Plugins are scripts placed in the `plugins` directory and are automatically loaded when the application runs.

**Creating Plugins:**

- **Location**: Place your plugin scripts in the `plugins` directory.
- **Naming Convention**:
  - **Script File**: `plugins/<plugin_name>.sh`
  - **Command Function**: `plugin_<plugin_name>()`
  - **Help Function**: `plugin_help_<plugin_name>()`
- **Capabilities**: Plugins can add new commands, extend existing functionality, or integrate with other tools.

### 📥 Example Plugin: iCal Import

**Plugin Name**: `import_ical`

**Description**: Import tasks from an iCalendar (`.ics`) file into the TODO application.

#### 📄 Implementing the Plugin

1. **Create the Plugins Directory** (if it doesn't exist):

   ```bash
   mkdir -p plugins
   ```

2. **Create the Plugin Script**:

   ```bash
   touch plugins/ical_import.sh
   chmod +x plugins/ical_import.sh
   ```

3. **Plugin Code** (`plugins/ical_import.sh`):

   ```bash
   #!/bin/bash

   # Plugin: ical_import
   # Description: Import tasks from an iCal (.ics) file without external dependencies

   # Function to handle the plugin command
   plugin_import_ical() {
       ical_file="$1"
       if [ -z "$ical_file" ]; then
           gum style --foreground 1 "❌ Please provide the path to the iCal file."
           echo "Usage: $0 import_ical <path_to_ical_file>"
           exit 1
       fi

       if [ ! -f "$ical_file" ]; then
           gum style --foreground 1 "❌ File '$ical_file' does not exist."
           exit 1
       fi

       # Read and parse the iCal file
       # We'll look for BEGIN:VEVENT to identify events
       # Extract SUMMARY, DESCRIPTION, DTSTART, DTEND for each event
       # This parser assumes a specific order and format, which may not cover all cases

       # Initialize variables
       while IFS= read -r line || [ -n "$line" ]; do
           case "$line" in
               BEGIN:VEVENT)
                   in_event=true
                   title=""
                   description=""
                   dtstart=""
                   dtend=""
                   ;;
               SUMMARY:*)
                   if [ "$in_event" = true ]; then
                       title="${line#SUMMARY:}"
                       # Handle folded lines
                       while IFS= read -r next_line; do
                           if [[ "$next_line" =~ ^[[:space:]] ]]; then
                               title+="${next_line}"
                           else
                               line="$next_line"
                               break
                           fi
                       done
                   fi
                   ;;
               DESCRIPTION:*)
                   if [ "$in_event" = true ]; then
                       description="${line#DESCRIPTION:}"
                       # Handle folded lines
                       while IFS= read -r next_line; do
                           if [[ "$next_line" =~ ^[[:space:]] ]]; then
                               description+="${next_line}"
                           else
                               line="$next_line"
                               break
                           fi
                       done
                   fi
                   ;;
               DTSTART:*)
                   if [ "$in_event" = true ]; then
                       dtstart="${line#DTSTART:*}"
                       dtstart="${dtstart//[[:space:]]/}"
                   fi
                   ;;
               DTEND:*)
                   if [ "$in_event" = true ]; then
                       dtend="${line#DTEND:*}"
                       dtend="${dtend//[[:space:]]/}"
                   fi
                   ;;
               END:VEVENT)
                   if [ "$in_event" = true ]; then
                       # Process the event and insert into the database

                       # Convert DTSTART and DTEND to YYYY-MM-DD format
                       due_date=$(format_ical_date "$dtstart")
                       end_date=$(format_ical_date "$dtend")

                       # Sanitize inputs
                       title=$(echo "$title" | sed "s/'/''/g")           # Escape single quotes
                       description=$(echo "$description" | sed "s/'/''/g")
                       recurring_expression="none"

                       # Insert into the database
                       sqlite3 "$DATABASE" <<SQL
   INSERT INTO tasks (title, description, due_date, end_date, recurring_expression, status)
   VALUES ('$title', '$description', '$due_date', '$end_date', '$recurring_expression', 'pending');
   SQL

                       # Reset variables
                       in_event=false
                       title=""
                       description=""
                       dtstart=""
                       dtend=""
                   fi
                   ;;
               *)
                   # Continue processing
                   ;;
           esac
       done < "$ical_file"

       gum style --foreground 212 "✅ iCal tasks imported successfully!"
   }

   # Function to format iCal dates to YYYY-MM-DD
   format_ical_date() {
       ical_date="$1"
       # Remove any parameters before the ':', if present
       ical_date="${ical_date##*:}"
       # Handle date formats (e.g., 20231031T120000Z, 20231031)
       if [[ "$ical_date" =~ ^[0-9]{8}T?[0-9]{0,6}(Z)?$ ]]; then
           # Extract the date portion
           date_part="${ical_date:0:8}"
           # Format as YYYY-MM-DD
           formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
           echo "$formatted_date"
       else
           echo ""
       fi
   }

   # Function to display help for the plugin
   plugin_help_ical_import() {
       echo "  import_ical <path>   📥 Import tasks from an iCal (.ics) file"
   }
   ```

#### 🚀 Using the Plugin

1. **Importing an iCal File**:

   ```bash
   ./todo.sh import_ical tasks.ics
   ```

   - Replace `tasks.ics` with the path to your iCal file.

2. **Viewing Imported Tasks**:

   ```bash
   ./todo.sh --list all
   ```

#### ⚠️ Limitations

- **Basic Parsing**: The plugin uses simple Bash commands to parse the iCal file. It supports basic events but may not handle complex features.
- **No External Dependencies**: Designed to be standalone without requiring Python or additional packages.
- **Limited Features**:
  - Does not support recurring events, alarms, or time zones.
  - Assumes a specific format and order of properties in the iCal file.
- **For Demonstration Purposes**: This plugin serves as an example of how to create plugins for the TODO application. For robust iCal parsing, consider using external tools or scripting languages with dedicated libraries.

---

## 🔄 Recurring Expressions

Schedule tasks to recur using flexible and powerful cron-like expressions.

### 📚 Syntax

The recurring expression uses a simplified cron-like format with three fields:

```
<day_of_month> <month> <day_of_week>
```

- **day_of_month**: `1-31` or `*` for any day
- **month**: `1-12` or `*` for any month
- **day_of_week**: `1-7` where `1` is Monday and `7` is Sunday, or `*` for any day

**You can use:**

- **Ranges**: E.g., `1-5` means days `1` through `5`
- **Lists**: E.g., `1,3,5` means days `1`, `3`, and `5`
- **Combinations**: E.g., `1-5,15,20-25`

### 💡 Examples

1. **Every Day**

   ```
   * * *
   ```

   - **Human-readable**: "Every day"

2. **Every Monday and Wednesday**

   ```
   * * 1,3
   ```

   - **Human-readable**: "Every on Monday, Wednesday"

3. **Every 1st and 15th of the Month**

   ```
   1,15 * *
   ```

   - **Human-readable**: "Every on day 1, 15"

4. **Every Weekday**

   ```
   * * 1-5
   ```

   - **Human-readable**: "Every on Monday to Friday"

5. **Every June and July on the 15th**

   ```
   15 6,7 *
   ```

   - **Human-readable**: "Every on day 15 in June, July"

6. **Every Saturday and Sunday**

   ```
   * * 6,7
   ```

   - **Human-readable**: "Every on Saturday, Sunday"

7. **Every Day in December**

   ```
   * 12 *
   ```

   - **Human-readable**: "Every in December"

### 📝 Explanation Function

The script includes a smart function that translates the recurring expression into a friendly, human-readable description. When adding a recurring task, the script will display this explanation and ask for your confirmation.

**Example Prompt:**

```
The task is set to recur: Every on Monday to Friday. Is this correct?
(Y/n)
```

---

## 📚 Examples

### ➕ Adding a Task with Recurrence

```bash
./todo.sh --add -t "Weekly Team Meeting" -d "2023-11-01" -r "* * 3"

# Output:
# The task is set to recur: Every on Wednesday. Is this correct?
# (Y/n)
```

- **Explanation:**
  - `-t "Weekly Team Meeting"`: Sets the task title.
  - `-d "2023-11-01"`: Sets the due date.
  - `-r "* * 3"`: Sets the task to recur every Wednesday.
  - The script explains the recurrence and asks for confirmation.

### 📋 Listing Tasks with Recurrence

```bash
./todo.sh --list pending

# Output:
# [⏳ ID: 1] Weekly Team Meeting 🔁 Every on Wednesday 📅 Due: 2023-11-01
```

- The task listing shows the human-readable recurrence pattern.

---

## 🧪 Testing

To run test, run this test script.

```bash
./test.sh
```

---

## ⚠️ Known Issues and Limitations

- **Date Command Compatibility:**

  - The script relies on GNU `date` for date calculations.
  - The script automatically detects `gdate` and uses it if available (common on macOS when GNU Coreutils are installed).

- **Recurring Expression Limitations:**

  - The script supports ranges and lists but not step values (e.g., `*/2`).
  - Advanced cron features like names for days or months (`Mon`, `Jan`) are not supported.

- **Time Zones:**

  - The script uses system time for date calculations. Ensure your system time zone is correctly configured.

- **Validation:**

  - The script validates dates and recurring expressions but may not catch all invalid inputs.

- **iCal Import Plugin Limitations:**
  - The provided iCal import plugin is a basic example and may not handle complex iCal files.
  - It does not support recurring events, time zones, or alarms.
  - Users requiring robust iCal support should consider using specialized tools or enhancing the plugin.

---

## 📝 License

This project is open-source and available under the MIT License.

---

**🎉 Enjoy using your fully-featured TODO application! Start conquering your tasks today!**

If you encounter any issues or have suggestions for improvements, feel free to contribute or reach out.

---

**Additional Notes:**

- **Dependencies:**

  - Ensure all dependencies are installed and accessible before running the script.
  - If `gum` is not installed, the script will not function as intended.

- **Script Execution:**

  - You may need to specify the path to the script when executing, e.g., `./todo.sh` or `/path/to/todo.sh`.

- **Data Persistence:**
  - The application uses an SQLite database (`todo.db`) in the same directory as the script.
  - Back up the `todo.db` file if you want to preserve your tasks across different environments or before making changes to the script.

---

Feel free to customize the script to suit your needs. **Happy task managing!** 🎈

---

By including the iCal import plugin in the README and explaining its limitations, readers are informed about how to create plugins and understand that the provided plugin serves as an example. This demonstration highlights the extensibility of the application and encourages users to develop their own plugins to enhance functionality.

If you have any more questions or need further assistance, please let me know!
