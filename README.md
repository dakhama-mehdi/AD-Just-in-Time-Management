<h1 style="display: flex; justify-content: space-between; align-items: center;">
  <img src="https://github.com/user-attachments/assets/ff348d9c-7ca3-4a70-a60f-4accdb6ce212" alt="left Image" width="100" height="100" />
  AD Juts-in-Time Management
</h1>

---

**AD JIT Management** is a free tool to easily manage identities and privileged access (PAM) in Active Directory using the Just-In-Time (JIT) model through an intuitive interface.
It lets you temporarily add users to privileged groups, ensuring time-limited and secure access to sensitive resources. 

![Image](https://github.com/user-attachments/assets/46b56aae-9f26-4311-bb83-72815421a906)

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
