// NavigationBar.js
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import theme from '../styles/theme';
import shadows from '../styles/shadows';
import Icon from 'react-native-vector-icons/MaterialIcons'; // Example icon library

/**
 * Navigation Bar Component
 *
 * @param {Object} props - Props for the navigation bar.
 * @param {Array} props.tabs - Array of tab objects. Each tab contains:
 *   - key: Unique identifier for the tab.
 *   - label: Label for the tab.
 *   - icon: Icon name for the tab.
 *   - route: Navigation route name.
 * @param {string} props.activeTab - Key of the currently active tab.
 * @param {Function} props.onTabPress - Callback when a tab is pressed.
 * @returns {JSX.Element}
 */
const NavigationBar = ({ tabs = [], activeTab = '', onTabPress }) => {
  const navigation = useNavigation();

  const handlePress = (tab) => {
    if (onTabPress) {
      onTabPress(tab);
    } else if (tab.route) {
      navigation.navigate(tab.route);
    }
  };

  return (
    <View style={[styles.container, shadows.medium]}>
      {tabs.map((tab) => (
        <TouchableOpacity
          key={tab.key}
          style={styles.tab}
          onPress={() => handlePress(tab)}
        >
          <Icon
            name={tab.icon}
            size={24}
            color={tab.key === activeTab ? theme.colors.primary : theme.colors.text}
          />
          <Text
            style={[
              styles.label,
              { color: tab.key === activeTab ? theme.colors.primary : theme.colors.text },
            ]}
          >
            {tab.label}
          </Text>
        </TouchableOpacity>
      ))}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: theme.colors.background,
    height: 60,
    borderTopWidth: 1,
    borderTopColor: theme.colors.border,
  },
  tab: {
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
    paddingVertical: theme.spacing.sm,
  },
  label: {
    fontSize: theme.fontSizes.sm,
    marginTop: 4,
  },
});

export default NavigationBar;