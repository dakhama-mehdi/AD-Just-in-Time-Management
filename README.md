<h1 style="display: flex; justify-content: space-between; align-items: center;">
  AD Juts-in-Time Management
  <img src="https://github.com/user-attachments/assets/ff348d9c-7ca3-4a70-a60f-4accdb6ce212" alt="Right Image" width="100" height="100" />
</h1>


## Description 

**FIM Identity Manager** is a free identity management tool designed to manage Privileged Access Management (PAM) on Active Directory.  
This tool allows you to add users to groups following the Just-In-Time (JIT) principle, ensuring time-limited access to sensitive resources.

## Features

- **Just-In-Time (JIT) Access Management**: Temporarily add users to Active Directory groups with a Time To Live (TTL).
- **User-Friendly Interface**: A graphical user interface for simplified management.
- **Error Logging and Handling**: Captures and displays errors for easier troubleshooting.

## Prerequisites

- **Windows** with RSAT AD Role installed.
- The user must have delegation rights to modify group memberships in the relevant OU.
- **No need for administrative rights.**

## Installation

There is no need for installation. Simply follow these steps:

1. **Obtain the executable file or the PowerShell script**:
   - You can either download the `.exe` file or copy the `FIM.ps1` script.

2. **Run the file**:
   - If using the `.exe` file, simply double-click to execute.
   - If using the PowerShell script:
     - Open PowerShell.
     - Execute the script:
       ```powershell
       .\FIM.ps1
       ```

## Usage

- Launch the tool (either `.exe` or `.ps1`).
- Use the interface to manage user access to Active Directory groups with a specified TTL.
- Ensure the machine has the RSAT AD Role, and the user has the necessary delegation rights.
- Monitor the output and logs for any errors or successful operations.

## Contributing

Contributions are welcome! Please fork the repository and create a pull request with your changes.  
Ensure that your code follows the project's coding standards.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
