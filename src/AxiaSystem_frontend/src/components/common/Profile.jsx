import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Image } from 'react-native';
import Avatar from './Avatar';
import Typography from './Typography';
import theme from '../styles/theme';

/**
 * Profile Component
 *
 * @param {Object} props - Props for the Profile component.
 * @param {string} props.avatarUrl - URL for the user's avatar image.
 * @param {string} props.name - Name of the user.
 * @param {string} props.username - Username or title of the user.
 * @param {Array} props.stats - Array of stats objects with { label, value }.
 * @param {React.ReactNode} props.actions - Action buttons (e.g., Follow, Message).
 * @param {Object} props.style - Additional styles for the profile container.
 * @param {Object} props.avatarStyle - Additional styles for the avatar.
 * @returns {JSX.Element}
 */
const Profile = ({
  avatarUrl,
  name,
  username,
  stats = [],
  actions = null,
  style = {},
  avatarStyle = {},
}) => {
  return (
    <View style={[styles.container, style]}>
      {/* Avatar Section */}
      <Avatar url={avatarUrl} size={80} style={avatarStyle} />

      {/* Name and Username */}
      <View style={styles.info}>
        <Typography variant="title" color={theme.colors.text}>
          {name}
        </Typography>
        {username && (
          <Typography variant="caption" color={theme.colors.subtext}>
            @{username}
          </Typography>
        )}
      </View>

      {/* Stats Section */}
      {stats.length > 0 && (
        <View style={styles.statsContainer}>
          {stats.map((stat, index) => (
            <View key={index} style={styles.stat}>
              <Typography variant="subtitle" color={theme.colors.text}>
                {stat.value}
              </Typography>
              <Typography variant="caption" color={theme.colors.subtext}>
                {stat.label}
              </Typography>
            </View>
          ))}
        </View>
      )}

      {/* Action Buttons */}
      {actions && <View style={styles.actions}>{actions}</View>}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    padding: theme.spacing.md,
    backgroundColor: theme.colors.surface,
    borderRadius: theme.borderRadius.md,
    ...theme.shadows.medium,
  },
  info: {
    marginTop: theme.spacing.sm,
    alignItems: 'center',
  },
  statsContainer: {
    flexDirection: 'row',
    marginTop: theme.spacing.md,
    justifyContent: 'space-around',
    width: '100%',
  },
  stat: {
    alignItems: 'center',
  },
  actions: {
    marginTop: theme.spacing.md,
    flexDirection: 'row',
    justifyContent: 'center',
    width: '100%',
  },
});

export default Profile;