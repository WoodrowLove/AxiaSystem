import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, Image } from 'react-native';
import theme from '../styles/theme';

/**
 * Tabs with Icons Component
 *
 * @param {Object} props - Props for the Tabs component.
 * @param {Array} props.tabs - Array of tab objects: [{ key: string, label: string, icon: ImageSource }].
 * @param {string} props.activeTabKey - Key of the currently active tab.
 * @param {Function} props.onTabChange - Callback function for tab changes.
 * @param {Object} props.style - Additional styles for the tab container.
 * @param {Object} props.tabStyle - Additional styles for individual tabs.
 * @param {Object} props.iconStyle - Styles for the icons.
 * @returns {JSX.Element}
 */
const TabsWithIcons = ({
  tabs = [],
  activeTabKey = '',
  onTabChange = () => {},
  style = {},
  tabStyle = {},
  iconStyle = {},
}) => {
  return (
    <View style={[styles.container, style]}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.scrollContainer}
      >
        {tabs.map((tab) => {
          const isActive = tab.key === activeTabKey;
          return (
            <TouchableOpacity
              key={tab.key}
              onPress={() => onTabChange(tab.key)}
              style={[
                styles.tab,
                isActive && styles.activeTab,
                tabStyle,
              ]}
            >
              {tab.icon && (
                <Image
                  source={tab.icon}
                  style={[
                    styles.icon,
                    isActive ? styles.activeIcon : styles.inactiveIcon,
                    iconStyle,
                  ]}
                />
              )}
              <Text
                style={[
                  styles.label,
                  isActive ? styles.activeLabel : styles.inactiveLabel,
                ]}
              >
                {tab.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.border,
    backgroundColor: theme.colors.surface,
  },
  scrollContainer: {
    flexDirection: 'row',
    paddingHorizontal: theme.spacing.md,
  },
  tab: {
    paddingVertical: theme.spacing.sm,
    paddingHorizontal: theme.spacing.lg,
    borderBottomWidth: 3,
    borderBottomColor: 'transparent',
    marginRight: theme.spacing.md,
    alignItems: 'center',
  },
  activeTab: {
    borderBottomColor: theme.colors.primary,
  },
  label: {
    fontSize: theme.fontSizes.md,
    marginTop: theme.spacing.xs,
  },
  activeLabel: {
    color: theme.colors.primary,
    fontWeight: 'bold',
  },
  inactiveLabel: {
    color: theme.colors.textSecondary,
  },
  icon: {
    width: 24,
    height: 24,
  },
  activeIcon: {
    tintColor: theme.colors.primary,
  },
  inactiveIcon: {
    tintColor: theme.colors.textSecondary,
  },
});

export default TabsWithIcons;