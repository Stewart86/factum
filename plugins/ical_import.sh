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
  while IFS= read -r line; do
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
        # Handle folded lines (lines that start with a space or tab)
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
        title=$(echo "$title" | sed "s/'/''/g") # Escape single quotes
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
  done <"$ical_file"

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
