import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/soniq_localizations.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/analytics_summary_model.dart';
import '../../../core/models/song_model.dart';
import '../controllers/analytics_controller.dart';
import 'widgets/daily_listening_chart.dart';
import 'widgets/day_part_card.dart';
import 'widgets/entity_analytics_sheet.dart';
import 'widgets/hourly_distribution_chart.dart';
import 'widgets/metric_stat_card.dart';
import 'widgets/ranking_item_tile.dart';
import 'soniq_replay_story_view.dart';
import 'analytics_settings_view.dart';

class AnalyticsDashboardView extends StatelessWidget {
  const AnalyticsDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AnalyticsController());
    final strings = SoniqLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          strings.text('listeningAnalytics'),
          style: AppTypography.headlineMedium,
        ),
        actions: [
          // Replay Button (Spotify Wrapped style)
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.gold.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.gold, width: 0.8),
              ),
            ),
            icon: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.gold,
              size: 16,
            ),
            label: Text(
              strings.text('replay'),
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            onPressed: () async {
              await controller.loadReplay();
              final rep = controller.replayModel.value;
              if (rep != null) {
                Get.to(
                  () => SoniqReplayStoryView(replay: rep),
                  transition: Transition.downToUp,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textMuted,
            ),
            tooltip: strings.text('settings'),
            onPressed: () => Get.to(() => const AnalyticsSettingsView()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.summary.value == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }

        final summary = controller.summary.value;
        if (summary == null) {
          return Center(
            child: Text(
              strings.text('noListeningData'),
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.surface,
          onRefresh: () => controller.loadAnalytics(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              // 1. Time Filter Carousel
              _buildTimeFilterPills(context, controller),

              const SizedBox(height: 16),

              // 2. High-Impact KPI Overview Cards
              _buildPrimaryKpiBanner(context, summary),

              const SizedBox(height: 16),

              // 3. Tab Navigation (Overview, Top Music, Trends, Discovery)
              _buildSectionTabs(context, controller),

              const SizedBox(height: 16),

              // 4. Tab Content
              if (controller.selectedTabIndex.value == 0)
                _buildOverviewTab(context, controller, summary)
              else if (controller.selectedTabIndex.value == 1)
                _buildTopMusicTab(context, controller, summary)
              else if (controller.selectedTabIndex.value == 2)
                _buildTrendsTab(controller, summary)
              else
                _buildDiscoveryTab(context, controller),
            ],
          ),
        );
      }),
    );
  }

  // --- 1. TIME FILTER PILLS ---
  Widget _buildTimeFilterPills(
    BuildContext context,
    AnalyticsController controller,
  ) {
    final strings = SoniqLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children:
            const [
              AnalyticsTimeFilter.today,
              AnalyticsTimeFilter.last7Days,
              AnalyticsTimeFilter.thisMonth,
              AnalyticsTimeFilter.thisYear,
              AnalyticsTimeFilter.allTime,
            ].map((f) {
              final isSelected = controller.timeFilter.value == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_timeFilterLabel(strings, f)),
                  selected: isSelected,
                  selectedColor: AppColors.gold,
                  backgroundColor: const Color(0xFF1E1A2B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppColors.gold : AppColors.border,
                    ),
                  ),
                  onSelected: (val) async {
                    if (f == AnalyticsTimeFilter.custom) {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.gold,
                                onPrimary: Colors.black,
                                surface: Color(0xFF191724),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        controller.setCustomRange(picked);
                      }
                    } else {
                      controller.setTimeFilter(f);
                    }
                  },
                ),
              );
            }).toList(),
      ),
    );
  }

  // --- 2. PRIMARY KPI BANNER ---
  Widget _buildPrimaryKpiBanner(
    BuildContext context,
    AnalyticsSummaryModel summary,
  ) {
    final strings = SoniqLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B163B), Color(0xFF181024)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.text('totalListeningTime').toUpperCase(),
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              if (summary.currentStreakDays > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF5722),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFF5722),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${summary.currentStreakDays} ${strings.text('streak')}',
                        style: const TextStyle(
                          color: Color(0xFFFF5722),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary.formattedTotalTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),

          // Secondary metrics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(
                NumberFormat.decimalPattern(strings.locale.toString())
                    .format(summary.totalEvents),
                strings.text('playCount'),
              ),
              _buildMiniStat(
                '${NumberFormat.decimalPattern(strings.locale.toString()).format((summary.completionRate * 100).round())}%',
                strings.text('completionRate'),
              ),
              _buildMiniStat(
                '${NumberFormat.decimalPattern(strings.locale.toString()).format((summary.skipRate * 100).round())}%',
                strings.text('skipRate'),
              ),
              _buildMiniStat(summary.peakHourLabel, strings.text('peakHour')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String val, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }

  String _timeFilterLabel(
    SoniqLocalizations strings,
    AnalyticsTimeFilter filter,
  ) => switch (filter) {
    AnalyticsTimeFilter.today => strings.text('filterDaily'),
    AnalyticsTimeFilter.last7Days => strings.text('filterWeekly'),
    AnalyticsTimeFilter.last30Days => strings.text('filter30Days'),
    AnalyticsTimeFilter.thisMonth => strings.text('filterMonthly'),
    AnalyticsTimeFilter.lastMonth => strings.text('filterLastMonth'),
    AnalyticsTimeFilter.last90Days => strings.text('filter90Days'),
    AnalyticsTimeFilter.thisYear => strings.text('filterYearly'),
    AnalyticsTimeFilter.allTime => strings.text('filterAllTime'),
    AnalyticsTimeFilter.custom => strings.text('filterCustom'),
  };

  // --- 3. SECTION TABS ---
  Widget _buildSectionTabs(
    BuildContext context,
    AnalyticsController controller,
  ) {
    final strings = SoniqLocalizations.of(context);
    final tabs = [
      strings.text('overview'),
      strings.text('topMusic'),
      strings.text('trendsHabits'),
      strings.text('discovery'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A2B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isSelected = controller.selectedTabIndex.value == idx;

          return Expanded(
            child: InkWell(
              onTap: () => controller.selectedTabIndex.value = idx,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textMuted,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 4. OVERVIEW TAB ---
  Widget _buildOverviewTab(
    BuildContext context,
    AnalyticsController controller,
    AnalyticsSummaryModel summary,
  ) {
    final strings = SoniqLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Song Highlight Card
        if (summary.mostPlayedSong != null) ...[
          _buildMostPlayedHighlight(
            context,
            controller,
            summary.mostPlayedSong!,
            summary.mostPlayedArtist,
          ),
          const SizedBox(height: 16),
        ],

        // 4 Grid Metric Cards
        Row(
          children: [
            Expanded(
              child: MetricStatCard(
                icon: Icons.music_note_rounded,
                iconColor: AppColors.gold,
                title: strings.text('uniqueTracks'),
                value: NumberFormat.decimalPattern(strings.locale.toString())
                    .format(summary.uniqueTracksPlayed),
                subtitle:
                    '${NumberFormat.decimalPattern(strings.locale.toString()).format(summary.totalEvents)} ${strings.text('totalSessions')}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricStatCard(
                icon: Icons.person_rounded,
                iconColor: AppColors.primary,
                title: strings.text('artistsPlayed'),
                value: NumberFormat.decimalPattern(strings.locale.toString())
                    .format(summary.uniqueArtistsPlayed),
                subtitle:
                    '${NumberFormat.decimalPattern(strings.locale.toString()).format(summary.uniqueAlbumsPlayed)} ${strings.text('albums')}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricStatCard(
                icon: Icons.today_rounded,
                iconColor: const Color(0xFF00E676),
                title: strings.text('dailyAverage'),
                value: summary.formattedAverageDailyTime,
                subtitle: strings.text('perActiveListeningDay'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricStatCard(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF00E5FF),
                title: strings.text('averageSession'),
                value:
                    '${NumberFormat.decimalPattern(strings.locale.toString()).format(summary.averageSessionDurationMs ~/ 60000)} ${strings.text('mins')}',
                subtitle: strings.text('continuousListening'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Interactive Daily Listening Bar Chart
        DailyListeningChart(metrics: summary.dailyMetrics),

        const SizedBox(height: 16),

        // Time of Day Card
        DayPartCard(
          dayParts: summary.dayParts,
          weekdayVsWeekend: summary.weekdayVsWeekend,
        ),
      ],
    );
  }

  Widget _buildMostPlayedHighlight(
    BuildContext context,
    AnalyticsController controller,
    TopItemMetric song,
    TopItemMetric? artist,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF191724),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: AppColors.gold,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOP TRACK',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${song.subtitle} • ${song.playCount} plays',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.gold,
              size: 36,
            ),
            onPressed: () => controller.playSongFromAnalytics(song.id),
          ),
        ],
      ),
    );
  }

  // --- 5. TOP MUSIC TAB ---
  Widget _buildTopMusicTab(
    BuildContext context,
    AnalyticsController controller,
    AnalyticsSummaryModel summary,
  ) {
    final catIdx = controller.topMusicCategoryIndex.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Switcher: Songs, Artists, Albums, Genres
        Row(
          children: ['Songs', 'Artists', 'Albums', 'Genres']
              .asMap()
              .entries
              .map((entry) {
                final isSel = catIdx == entry.key;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FilterChip(
                      label: Text(entry.value),
                      selected: isSel,
                      selectedColor: AppColors.gold,
                      backgroundColor: const Color(0xFF1E1A2B),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.white,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSel ? AppColors.gold : AppColors.border,
                        ),
                      ),
                      onSelected: (_) =>
                          controller.topMusicCategoryIndex.value = entry.key,
                    ),
                  ),
                );
              })
              .toList(),
        ),

        const SizedBox(height: 16),

        if (catIdx == 0) ...[
          if (summary.topSongs.isEmpty)
            _buildEmptyTabNotice('No top songs recorded in this period')
          else
            ...summary.topSongs.take(20).toList().asMap().entries.map((e) {
              final rank = e.key + 1;
              final item = e.value;
              return RankingItemTile(
                rank: rank,
                metric: item,
                onPlay: () => controller.playSongFromAnalytics(item.id),
                onTap: () => EntityAnalyticsSheet.show(
                  context,
                  entityType: 'Song',
                  entityId: item.id,
                  title: item.title,
                  subtitle: item.subtitle,
                ),
              );
            }),
        ] else if (catIdx == 1) ...[
          if (summary.topArtists.isEmpty)
            _buildEmptyTabNotice('No artist statistics recorded')
          else
            ...summary.topArtists.take(15).toList().asMap().entries.map((e) {
              final rank = e.key + 1;
              final item = e.value;
              return RankingItemTile(
                rank: rank,
                metric: item,
                onTap: () => EntityAnalyticsSheet.show(
                  context,
                  entityType: 'Artist',
                  entityId: item.id,
                  title: item.title,
                  subtitle: item.subtitle,
                ),
              );
            }),
        ] else if (catIdx == 2) ...[
          if (summary.topAlbums.isEmpty)
            _buildEmptyTabNotice('No album listening data recorded')
          else
            ...summary.topAlbums.take(15).toList().asMap().entries.map((e) {
              final rank = e.key + 1;
              final item = e.value;
              return RankingItemTile(
                rank: rank,
                metric: item,
                onTap: () => EntityAnalyticsSheet.show(
                  context,
                  entityType: 'Album',
                  entityId: item.id,
                  title: item.title,
                  subtitle: item.subtitle,
                ),
              );
            }),
        ] else ...[
          if (summary.topGenres.isEmpty)
            _buildEmptyTabNotice('No genre distributions recorded')
          else
            ...summary.topGenres.take(10).toList().asMap().entries.map((e) {
              final rank = e.key + 1;
              final item = e.value;
              return RankingItemTile(rank: rank, metric: item);
            }),
        ],
      ],
    );
  }

  // --- 6. TRENDS & HABITS TAB ---
  Widget _buildTrendsTab(
    AnalyticsController controller,
    AnalyticsSummaryModel summary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 24 Hour Distribution Chart
        HourlyDistributionChart(
          metrics: summary.hourlyMetrics,
          peakHour: summary.peakListeningHour,
        ),

        const SizedBox(height: 16),

        // Day Parts & Weekday Comparison
        DayPartCard(
          dayParts: summary.dayParts,
          weekdayVsWeekend: summary.weekdayVsWeekend,
        ),

        const SizedBox(height: 16),

        // Listening Streaks Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF191724),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Listening Streaks',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF221A30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFFF5722),
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Current Streak',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${summary.currentStreakDays} Days',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF221A30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.emoji_events_rounded,
                                color: AppColors.gold,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Longest Streak',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${summary.longestStreakDays} Days',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 7. DISCOVERY TAB ---
  Widget _buildDiscoveryTab(
    BuildContext context,
    AnalyticsController controller,
  ) {
    final disc = controller.discoveryInsights.value;
    if (disc == null || disc.isEmpty) {
      return _buildEmptyTabNotice(
        'Listen to more songs to unlock personalized discovery insights.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (disc.forgottenFavorites.isNotEmpty)
          _buildDiscoverySection(
            title: 'Forgotten Favorites',
            subtitle:
                'Songs in your Favorites you haven\'t played in over 30 days',
            icon: Icons.favorite_border_rounded,
            iconColor: const Color(0xFFFF2A85),
            songs: disc.forgottenFavorites,
            onPlayAll: () => controller.playCollection(disc.forgottenFavorites),
            onCreatePlaylist: () => controller.createPlaylistFromDiscovery(
              'Forgotten Favorites Mix',
              disc.forgottenFavorites,
            ),
            controller: controller,
          ),

        if (disc.rediscoveredMusic.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildDiscoverySection(
            title: 'Rediscovered Gems',
            subtitle: 'Songs you recently came back to after a long silence',
            icon: Icons.replay_rounded,
            iconColor: AppColors.gold,
            songs: disc.rediscoveredMusic,
            onPlayAll: () => controller.playCollection(disc.rediscoveredMusic),
            onCreatePlaylist: () => controller.createPlaylistFromDiscovery(
              'Rediscovered Gems',
              disc.rediscoveredMusic,
            ),
            controller: controller,
          ),
        ],

        if (disc.mostReplayedSongs.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildDiscoverySection(
            title: 'Most On Repeat',
            subtitle: 'Songs you repeatedly replayed back-to-back',
            icon: Icons.repeat_one_rounded,
            iconColor: const Color(0xFF00E676),
            songs: disc.mostReplayedSongs,
            onPlayAll: () => controller.playCollection(disc.mostReplayedSongs),
            onCreatePlaylist: () => controller.createPlaylistFromDiscovery(
              'On Repeat Heavy',
              disc.mostReplayedSongs,
            ),
            controller: controller,
          ),
        ],

        if (disc.frequentlySkippedSongs.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildDiscoverySection(
            title: 'Frequently Skipped',
            subtitle: 'Songs you skipped before completion',
            icon: Icons.skip_next_rounded,
            iconColor: const Color(0xFFFF5252),
            songs: disc.frequentlySkippedSongs,
            onPlayAll: () =>
                controller.playCollection(disc.frequentlySkippedSongs),
            onCreatePlaylist: () => controller.createPlaylistFromDiscovery(
              'Frequently Skipped',
              disc.frequentlySkippedSongs,
            ),
            controller: controller,
          ),
        ],
      ],
    );
  }

  Widget _buildDiscoverySection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<SongModel> songs,
    required VoidCallback onPlayAll,
    required VoidCallback onCreatePlaylist,
    required AnalyticsController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF191724),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.playlist_add_rounded,
                  color: AppColors.gold,
                  size: 22,
                ),
                tooltip: 'Save as Playlist',
                onPressed: onCreatePlaylist,
              ),
              IconButton(
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
                tooltip: 'Play All',
                onPressed: onPlayAll,
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...songs
              .take(4)
              .map(
                (s) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF262135),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    s.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                    onPressed: () => controller.playSongFromAnalytics(s.id),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildEmptyTabNotice(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(
            Icons.insights_rounded,
            color: AppColors.textMuted,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
