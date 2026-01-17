# Feature - Implement full data-based calendar
**Goal**: The player will progress through a calendar with years, seasons, months, weeks, days, and times of day.

---

Create a data driven structure to create a robust calendar of days. 
The starting year should be randomly generated from the world seed, with a value no less than 101 and a value no greater than 899. The calendar should have a 3 months per season. Each month should consist of 28 days with 7 days per week. 

These should all be drawn from a data file instead of hard coded.

Seasons will be Spring, Summer, Autumn, and Winter.
Vary the base ambient overworld temperature based on season, and month, with daily variations in a reasonable range. It should also be cooler at night than in the day.

Update the UI to reflect the day name, day #, month name, and year (season)
