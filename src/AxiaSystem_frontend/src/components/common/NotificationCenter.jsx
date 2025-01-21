import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  FlatList,
  StyleSheet,
} from 'react-native';
import theme from '../styles/theme';
import shadows from '../styles/shadows';
import Typography from './Typography';
import Icon from 'react-native-vector-icons/MaterialIcons';

/**
 * Notification Center Component
 *
 * @param {Object} props - Props for the Notification Center.
 * @param {Array} props.notifications - Array of notification objects.
 * @param {Function} props.onDismiss - Callback when a notification is dismissed.
 * @param {React.ReactNode} props.emptyState - Custom component for the empty state.
 * @returns {JSX.Element}
 */
const NotificationCenter = ({
  notifications = [],
  onDismiss = () => {},
  emptyState = <Text style={styles.emptyText}>No notifications available</Text>,
}) => {
  const renderNotification = ({ item }) => (
    <View
      style={[
        styles.notification,
        item.isRead ? styles.read : styles.unread,
        shadows.light,
      ]}
    >
      <Icon
        name={item.type === 'error' ? 'error' : 'info'}
        size={24}
        color={theme.colors[item.type] || theme.colors.info}
        style={styles.icon}
      />
      <View style={styles.textContainer}>
        <Typography
          variant="body"
          color={item.isRead ? theme.colors.textMuted : theme.colors.text}
        >
          {item.message}
        </Typography>
        <Typography variant="caption" color={theme.colors.textMuted}>
          {item.timestamp}
        </Typography>
      </View>
      <TouchableOpacity
        style={styles.dismissButton}
        onPress={() => onDismiss(item.id)}
      >
        <Icon name="close" size={20} color={theme.colors.text} />
      </TouchableOpacity>
    </View>
  );

  return (
    <View style={styles.container}>
      {notifications.length > 0 ? (
        <FlatList
          data={notifications}
          renderItem={renderNotification}
          keyExtractor={(item) => item.id.toString()}
          contentContainerStyle={styles.list}
        />
      ) : (
        <View style={styles.emptyState}>{emptyState}</View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
    padding: theme.spacing.md,
  },
  list: {
    paddingBottom: theme.spacing.lg,
  },
  notification: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: theme.colors.surface,
    borderRadius: theme.borderRadius.md,
    padding: theme.spacing.md,
    marginBottom: theme.spacing.sm,
  },
  read: {
    opacity: 0.6,
  },
  unread: {
    opacity: 1,
  },
  icon: {
    marginRight: theme.spacing.sm,
  },
  textContainer: {
    flex: 1,
  },
  dismissButton: {
    padding: theme.spacing.sm,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyText: {
    color: theme.colors.textMuted,
    fontSize: theme.fontSizes.md,
    textAlign: 'center',
  },
});

export default NotificationCenter;