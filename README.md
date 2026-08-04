<h1 style="display: flex; justify-content: space-between; align-items: center;">
  <img src="https://github.com/user-attachments/assets/ff348d9c-7ca3-4a70-a60f-4accdb6ce212" alt="left Image" width="100" height="60" />
  AD Just-in-Time Management for Tiering Model
</h1>

**Active Directory JIT Management** is a free PowerShell WPF application designed to simplify the administration of privileged Active Directory accounts by granting **Just-in-Time (JIT)** access through native **Time-To-Live (TTL)** group memberships.

The tool helps reduce standing privileges and supports the implementation of Microsoft's administrative security recommendations, including the **Tiering Model**, by allowing administrators to grant temporary access to privileged groups through an intuitive graphical interface.

It also provides a dedicated Windows Event Log for auditing and tracing all JIT operations. 

<img src=".\Pictures\ADJIt_2.png" >

## Features

- Graphical WPF interface for Just-in-Time (JIT) administration.
- Native Active Directory Time-To-Live (TTL) group memberships.
- Search and select Active Directory users, groups and machines.
- Temporary privileged group assignments.
- Remaining TTL display for active memberships.
- Configurable expiration date and duration.
- Dedicated Windows Event Log for auditing JIT operations.
- Standard user mode for viewing JIT memberships.
- Robust error handling and user-friendly notifications.
- No third-party components required.

## Requirements

- Windows PowerShell 5.1.
- RSAT Active Directory PowerShell module installed.
- The **Privileged Access Management (PAM) optional feature** must be enabled in the Active Directory.
- The account running the tool must have the appropriate delegation (for example **Write Members** or **Manager can update membership list**) on the target groups.
- Local administrator privileges are required **only once** to create the dedicated Windows Event Log.

## Installation

There is no need for installation. Simply follow these steps:

1. **Obtain the executable file or the PowerShell script**:
   - You can either download the `.exe` file or copy the `ADJIT.ps1` script.

2. **Run the file**:
   - If using the `.exe` file, simply double-click to execute.
   - If using the PowerShell script:
     - Open PowerShell.
     - Execute the script:
       ```powershell
       .\ADJIT.ps1
       ```

## Usage

1. Launch the application (`.exe` or `.ps1`).
2. **The first time only**, open **File → Event Log** and accept the UAC prompt to create the dedicated Windows Event Log. This one-time operation requires local administrator privileges.
3. Ensure the **RSAT Active Directory** tools are installed and that your account has the required Active Directory delegation to manage the target groups.
4. Use the graphical interface to assign temporary (TTL) memberships to Active Directory groups.
5. Monitor the dedicated Windows Event Log to review successful operations, warnings, and errors.

## Why use AD Just-in-Time Management?

- Reduce standing privileged access.
- Implement native Just-in-Time (JIT) administration.
- Support Microsoft's Tiering Model and least privilege recommendations.
- Eliminate manual removal of temporary group memberships.
- Improve auditing and traceability through a dedicated Windows Event Log.
- Simplify Active Directory administration with an intuitive WPF interface.
- Rely entirely on native Microsoft technologies without third-party components.

## Event IDs

AD Just-in-Time Management records operations in the dedicated Windows Event Log using the following event IDs:

| Event ID | Level | Description |
|---|---|---|
| `1001` | Information | A user or group was successfully added to an Active Directory group with a TTL. |
| `1002` | Warning | A temporary member was successfully removed from the Active Directory group. |
| `2001` | Error | An error occurred while adding a user or group to the Active Directory group. |
| `2002` | Error | An error occurred while removing a temporary member from the Active Directory group. |

## Acknowledgements

Special thanks to the following people and communities for their support, expertise, and contributions:

- **Guillaume MATHIEU** – Co-founder of the **Harden** community, for his guidance and valuable advice throughout the project.
 - Alain Cuisenier
 - https://www.it-connect.fr/ 
 - [https://www.doctorkloud](https://www.doctorkloud.fr/)
 - https://hardenad.net/

<img src=".\Pictures\ADJIT_Logs.png" >

## Contributing

Contributions are welcome! Please fork the repository and create a pull request with your changes.  
Ensure that your code follows the project's coding standards.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
