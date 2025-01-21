import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import theme from '../styles/theme';
import shadows from '../styles/shadows';
import Typography from './Typography';

/**
 * Table Component
 *
 * @param {Object} props - Props for the table component.
 * @param {Array} props.columns - Array of column definitions (e.g., [{ key: 'name', title: 'Name', width: '30%' }]).
 * @param {Array} props.data - Array of row data objects (e.g., [{ name: 'John', age: 30 }]).
 * @param {Function} props.onRowPress - Callback when a row is pressed (optional).
 * @param {boolean} props.sortable - Enable sorting for columns (default: false).
 * @param {string} props.sortKey - The key of the currently sorted column (optional).
 * @param {'asc' | 'desc'} props.sortOrder - Current sort order (optional).
 * @param {Function} props.onSort - Callback when a column header is pressed for sorting.
 * @param {Object} props.style - Additional styles for the table container.
 * @returns {JSX.Element}
 */
const Table = ({
  columns = [],
  data = [],
  onRowPress = null,
  sortable = false,
  sortKey = null,
  sortOrder = 'asc',
  onSort = null,
  style = {},
}) => {
  const renderHeader = () => (
    <View style={[styles.headerRow, shadows.medium]}>
      {columns.map((col) => (
        <TouchableOpacity
          key={col.key}
          style={[styles.headerCell, { width: col.width || 'auto' }]}
          onPress={() => sortable && onSort && onSort(col.key)}
          disabled={!sortable}
        >
          <Typography
            variant="subheading"
            color={theme.colors.primary}
            style={styles.headerText}
          >
            {col.title}
          </Typography>
          {sortable && sortKey === col.key && (
            <Typography variant="caption" style={styles.sortIcon}>
              {sortOrder === 'asc' ? '↑' : '↓'}
            </Typography>
          )}
        </TouchableOpacity>
      ))}
    </View>
  );

  const renderRow = (rowData, rowIndex) => (
    <TouchableOpacity
      key={rowIndex}
      style={[styles.row, rowIndex % 2 === 0 ? styles.evenRow : styles.oddRow]}
      onPress={() => onRowPress && onRowPress(rowData)}
      disabled={!onRowPress}
    >
      {columns.map((col) => (
        <View
          key={col.key}
          style={[styles.cell, { width: col.width || 'auto' }]}
        >
          <Typography color={theme.colors.text}>
            {rowData[col.key] || ''}
          </Typography>
        </View>
      ))}
    </TouchableOpacity>
  );

  return (
    <View style={[styles.container, style]}>
      {renderHeader()}
      <ScrollView>
        {data.map((rowData, rowIndex) => renderRow(rowData, rowIndex))}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: theme.colors.surface,
    borderRadius: theme.borderRadius.md,
    overflow: 'hidden',
    ...shadows.medium,
  },
  headerRow: {
    flexDirection: 'row',
    backgroundColor: theme.colors.primaryLight,
    paddingVertical: theme.spacing.sm,
    paddingHorizontal: theme.spacing.md,
  },
  headerCell: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  headerText: {
    fontWeight: 'bold',
  },
  sortIcon: {
    marginLeft: theme.spacing.xs,
  },
  row: {
    flexDirection: 'row',
    paddingVertical: theme.spacing.sm,
    paddingHorizontal: theme.spacing.md,
  },
  evenRow: {
    backgroundColor: theme.colors.background,
  },
  oddRow: {
    backgroundColor: theme.colors.surface,
  },
  cell: {
    flex: 1,
    justifyContent: 'center',
  },
});

export default Table;