// CalendarDatePicker.js
import React, { useState } from 'react';
import { View, StyleSheet } from 'react-native';
import { Calendar } from 'react-native-calendars';
import theme from '../styles/theme';
import Typography from './Typography';

/**
 * CalendarDatePicker Component
 *
 * @param {Object} props - Props for the calendar component.
 * @param {Function} props.onDateChange - Callback when a single date is selected.
 * @param {Function} props.onRangeChange - Callback when a range of dates is selected.
 * @param {boolean} props.enableRangeSelection - Enable range selection mode.
 * @param {string} props.initialDate - Default selected date.
 * @param {Object} props.markedDates - Marked dates (e.g., events, holidays).
 * @param {Object} props.style - Additional styles for the calendar container.
 * @returns {JSX.Element}
 */
const CalendarDatePicker = ({
  onDateChange,
  onRangeChange,
  enableRangeSelection = false,
  initialDate = '',
  markedDates = {},
  style = {},
}) => {
  const [selectedDate, setSelectedDate] = useState(initialDate);
  const [range, setRange] = useState({ start: '', end: '' });

  const handleDayPress = (day) => {
    if (enableRangeSelection) {
      if (!range.start || (range.start && range.end)) {
        // Start a new range
        setRange({ start: day.dateString, end: '' });
      } else {
        // End the range
        const newRange = { start: range.start, end: day.dateString };
        setRange(newRange);
        if (onRangeChange) onRangeChange(newRange);
      }
    } else {
      setSelectedDate(day.dateString);
      if (onDateChange) onDateChange(day.dateString);
    }
  };

  // Create marked dates for range selection
  const markedRangeDates = () => {
    if (range.start && range.end) {
      const dates = {};
      let currentDate = new Date(range.start);
      const endDate = new Date(range.end);

      while (currentDate <= endDate) {
        const dateString = currentDate.toISOString().split('T')[0];
        dates[dateString] = {
          selected: true,
          marked: true,
          selectedColor: theme.colors.primary,
        };
        currentDate.setDate(currentDate.getDate() + 1);
      }
      return dates;
    }
    return {};
  };

  return (
    <View style={[styles.container, style]}>
      <Typography variant="subheading" style={styles.heading}>
        {enableRangeSelection ? 'Select a Date Range' : 'Select a Date'}
      </Typography>
      <Calendar
        current={initialDate}
        minDate={new Date().toISOString().split('T')[0]} // Disable past dates
        onDayPress={handleDayPress}
        markedDates={
          enableRangeSelection
            ? { ...markedDates, ...markedRangeDates() }
            : {
                ...markedDates,
                [selectedDate]: {
                  selected: true,
                  selectedColor: theme.colors.primary,
                },
              }
        }
        theme={{
          selectedDayBackgroundColor: theme.colors.primary,
          todayTextColor: theme.colors.primary,
          dayTextColor: theme.colors.text,
          textDisabledColor: theme.colors.disabled,
          arrowColor: theme.colors.primary,
          monthTextColor: theme.colors.primary,
        }}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: theme.colors.background,
    borderRadius: theme.borderRadius.md,
    padding: theme.spacing.md,
    ...theme.shadows.light,
  },
  heading: {
    marginBottom: theme.spacing.sm,
    color: theme.colors.text,
  },
});

export default CalendarDatePicker;