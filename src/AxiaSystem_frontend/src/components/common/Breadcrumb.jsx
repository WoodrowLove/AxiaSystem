// Breadcrumb.js
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import theme from '../styles/theme';

/**
 * Breadcrumb Component
 *
 * @param {Object} props - Props for the breadcrumb component.
 * @param {Array} props.items - Array of breadcrumb items. Each item is an object with `label` and optional `onPress`.
 * @param {Object} props.style - Additional styles for the breadcrumb container.
 * @param {Object} props.itemStyle - Additional styles for individual breadcrumb items.
 * @param {Object} props.separatorStyle - Additional styles for the separator.
 * @param {string} props.separator - Separator symbol (default: '>').
 * @returns {JSX.Element}
 */
const Breadcrumb = ({
  items = [],
  style = {},
  itemStyle = {},
  separatorStyle = {},
  separator = '>',
}) => {
  return (
    <View style={[styles.container, style]}>
      {items.map((item, index) => (
        <View key={index} style={styles.itemContainer}>
          <TouchableOpacity
            disabled={!item.onPress}
            onPress={item.onPress}
            style={styles.itemWrapper}
          >
            <Text
              style={[
                styles.itemText,
                !item.onPress && styles.disabledText,
                itemStyle,
              ]}
            >
              {item.label}
            </Text>
          </TouchableOpacity>
          {index < items.length - 1 && (
            <Text style={[styles.separator, separatorStyle]}>{separator}</Text>
          )}
        </View>
      ))}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: theme.spacing.sm,
  },
  itemContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  itemWrapper: {
    paddingHorizontal: theme.spacing.xs,
  },
  itemText: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.primary,
    fontWeight: 'bold',
  },
  disabledText: {
    color: theme.colors.disabled,
  },
  separator: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.text,
    marginHorizontal: theme.spacing.xs,
  },
});

export default Breadcrumb;