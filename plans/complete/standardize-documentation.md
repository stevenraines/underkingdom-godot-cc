# Feature - Standardize Documentation
**Goal**: Produce human readable documentation that explains how systems work and what the properties of various data types represent.   

---
1. For each system, create a new document in the systems folder named {system-name}.md. This should be a human readable document that explains how the system functions. For instance, the combat-system.md file should explain the rules of combat, how chance to hit is determined, the impact of abilities on combat, etc. Everything the system takes into account should be explained. 

2. For each type of data, produce a document in the root folder named {data-type}.md. This should contain a description of every possible property that the data can have that is used by any system. For each property, include the name of the property, what systems use it and a description of how it is used in the system. If a given property is not used anywhere, indicate that.

3. Update CLAUDE.md so that any future changes to systems or data types get updated. Also, add instructions that whenever new user capabilities are added, the appropriate information is added to the help screen and the README.md file.