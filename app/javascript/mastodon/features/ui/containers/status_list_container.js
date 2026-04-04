import { connect } from 'react-redux';
import StatusList from '../../../components/status_list';
import { scrollTopTimeline, loadPending } from '../../../actions/timelines';
import { Map as ImmutableMap, List as ImmutableList, Set as ImmutableSet } from 'immutable';
import { createSelector } from 'reselect';
import { debounce } from 'lodash';
import { me } from '../../../initial_state';

const makeGetStatusIds = (pending = false) => createSelector([
  (state, { type }) => state.getIn(['settings', type], ImmutableMap()),
  (state, { type }) => state.getIn(['timelines', type, pending ? 'pendingItems' : 'items'], ImmutableList()),
  (state)           => state.get('statuses'),
], (columnSettings, statusIds, statuses) => {
  return statusIds.filter(id => {
    if (id === null) return true;

    const statusForId = statuses.get(id);
    let showStatus    = true;

    if (statusForId.get('account') === me) return true;

    if (columnSettings.getIn(['shows', 'reblog']) === false) {
      showStatus = showStatus && statusForId.get('reblog') === null;
    }

    if (columnSettings.getIn(['shows', 'reply']) === false) {
      showStatus = showStatus && (statusForId.get('in_reply_to_id') === null || statusForId.get('in_reply_to_account_id') === me);
    }

    return showStatus;
  });
});

const makeGetThreadRelationships = () => createSelector([
  (state, { filteredIds }) => filteredIds,
  (state) => state.get('statuses'),
], (statusIds, statuses) => {
  let threadParentIds = ImmutableSet();
  let threadChildIds = ImmutableSet();

  for (let i = 0; i < statusIds.size - 1; i++) {
    const currentId = statusIds.get(i);
    const nextId = statusIds.get(i + 1);
    if (currentId === null || nextId === null) continue;

    const nextStatus = statuses.get(nextId);
    if (nextStatus && nextStatus.get('in_reply_to_id') === currentId) {
      threadParentIds = threadParentIds.add(currentId);
      threadChildIds = threadChildIds.add(nextId);
    }
  }

  return { threadParentIds, threadChildIds };
});

const makeMapStateToProps = () => {
  const getStatusIds = makeGetStatusIds();
  const getPendingStatusIds = makeGetStatusIds(true);
  const getThreadRelationships = makeGetThreadRelationships();

  const mapStateToProps = (state, { timelineId }) => {
    const statusIds = getStatusIds(state, { type: timelineId });
    const { threadParentIds, threadChildIds } = getThreadRelationships(state, { filteredIds: statusIds });

    return {
      statusIds,
      threadParentIds,
      threadChildIds,
      isLoading: state.getIn(['timelines', timelineId, 'isLoading'], true),
      isPartial: state.getIn(['timelines', timelineId, 'isPartial'], false),
      hasMore:   state.getIn(['timelines', timelineId, 'hasMore']),
      numPending: getPendingStatusIds(state, { type: timelineId }).size,
    };
  };

  return mapStateToProps;
};

const mapDispatchToProps = (dispatch, { timelineId }) => ({

  onScrollToTop: debounce(() => {
    dispatch(scrollTopTimeline(timelineId, true));
  }, 100),

  onScroll: debounce(() => {
    dispatch(scrollTopTimeline(timelineId, false));
  }, 100),

  onLoadPending: () => dispatch(loadPending(timelineId)),

});

export default connect(makeMapStateToProps, mapDispatchToProps)(StatusList);
