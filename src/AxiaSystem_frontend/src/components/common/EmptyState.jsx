import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons'; // For default icons
import theme from '../styles/theme';

/**
 * Empty State Component
 *
 * @param {Object} props - Props for the Empty State component.
 * @param {string} props.iconName - Icon name from a library (default: MaterialIcons).
 * @param {string} props.message - Message to display.
 * @param {string} props.subMessage - Additional description (optional).
 * @param {Function} props.onActionPress - Function to execute when the action button is pressed.
 * @param {string} props.actionLabel - Text for the action button.
 * @param {Object} props.style - Additional styles for the container.
 * @returns {JSX.Element}
 */
const EmptyState = ({
  iconName = 'info-outline',
  message = 'No items found',
  subMessage = '',
  onActionPress = null,
  actionLabel = '',
  style = {},
}) => {
  return (
    <View style={[styles.container, style]}>
      <MaterialIcons
        name={iconName}
        size={64}
        color={theme.colors.primary}
        style={styles.icon}
      />
      <Text style={styles.message}>{message}</Text>
      {subMessage ? <Text style={styles.subMessage}>{subMessage}</Text> : null}
      {onActionPress && actionLabel ? (
        <TouchableOpacity style={styles.button} onPress={onActionPress}>
          <Text style={styles.buttonText}>{actionLabel}</Text>
        </TouchableOpacity>
      ) : null}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: theme.spacing.md,
    backgroundColor: theme.colors.background,
  },
  icon: {
    marginBottom: theme.spacing.md,
  },
  message: {
    fontSize: theme.fontSizes.lg,
    color: theme.colors.text,
    textAlign: 'center',
    marginBottom: theme.spacing.sm,
  },
  subMessage: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.textSecondary,
    textAlign: 'center',
    marginBottom: theme.spacing.md,
  },
  button: {
    marginTop: theme.spacing.sm,
    backgroundColor: theme.colors.primary,
    paddingVertical: theme.spacing.sm,
    paddingHorizontal: theme.spacing.lg,
    borderRadius: theme.borderRadius.sm,
  },
  buttonText: {
    color: theme.colors.onPrimary,
    fontSize: theme.fontSizes.md,
    fontWeight: 'bold',
  },
});

export default EmptyState;