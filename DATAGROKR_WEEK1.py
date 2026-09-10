"""
CLI Student Grade Calculator
-----------------------------
"""
def get_grade(percentage: float) -> str:
    """Return a letter grade based on percentage."""
    if percentage >= 90:
        return "A+"
    elif percentage >= 80:
        return "A"
    elif percentage >= 70:
        return "B"
    elif percentage >= 60:
        return "C"
    elif percentage >= 50:
        return "D"
    elif percentage >= 40:
        return "E"
    else:
        return "F"


def get_float_input(prompt: str, min_val: float = 0, max_val: float = 100) -> float:
    """Safely get a float input within a given range."""
    while True:
        try:
            value = float(input(prompt))
            if min_val <= value <= max_val:
                return value
            print(f"Please enter a value between {min_val} and {max_val}.")
        except ValueError:
            print("Invalid input. Please enter a number.")


def get_int_input(prompt: str, min_val: int = 1) -> int:
    """Safely get an integer input above a minimum value."""
    while True:
        try:
            value = int(input(prompt))
            if value >= min_val:
                return value
            print(f"Please enter a value of at least {min_val}.")
        except ValueError:
            print("Invalid input. Please enter a whole number.")


def main():
    print("=" * 45)
    print("        STUDENT GRADE CALCULATOR")
    print("=" * 45)

    student_name = input("Enter student name: ").strip() or "Student"
    num_subjects = get_int_input("Enter number of subjects: ")

    subjects = []
    total_marks = 0.0
    max_marks_per_subject = 100

    for i in range(1, num_subjects + 1):
        print(f"\n--- Subject {i} ---")
        name = input("Subject name: ").strip() or f"Subject {i}"
        marks = get_float_input(f"Marks obtained (out of {max_marks_per_subject}): ")
        grade = get_grade(marks)
        subjects.append({"name": name, "marks": marks, "grade": grade})
        total_marks += marks

    total_possible = num_subjects * max_marks_per_subject
    average = total_marks / num_subjects
    overall_grade = get_grade(average)

    # Report
    print("\n" + "=" * 45)
    print(f"REPORT CARD - {student_name}")
    print("=" * 45)
    print(f"{'Subject':<20}{'Marks':<10}{'Grade':<10}")
    print("-" * 45)
    for s in subjects:
        print(f"{s['name']:<20}{s['marks']:<10.1f}{s['grade']:<10}")
    print("-" * 45)
    print(f"Total Marks   : {total_marks:.1f} / {total_possible}")
    print(f"Average       : {average:.2f}%")
    print(f"Overall Grade : {overall_grade}")
    print("=" * 45)


if __name__ == "__main__":
    main()