// ═══════════════════════════════════════════════════════════════════════════════
// Pipeline Flow View — React Flow visualization of 6-agent pipeline
// ═══════════════════════════════════════════════════════════════════════════════

import React, { useEffect, useMemo } from 'react';
import ReactFlow, {
  Node,
  Edge,
  Background,
  Controls,
  MiniMap,
  ConnectionLineType,
  MarkerType,
  ReactFlowProvider,
  useReactFlow,
} from 'reactflow';
import 'reactflow/dist/style.css';
import { Box } from '@mui/material';
import AgentNode from './AgentNode';
import { AgentStep } from '../types';

interface PipelineFlowViewProps {
  agents: AgentStep[];
  onNodeClick: (agentId: number) => void;
}

const nodeTypes = {
  agentNode: AgentNode,
};

// Inner component — must be inside ReactFlowProvider to use useReactFlow()
const FitViewOnMount: React.FC<{ nodeCount: number }> = ({ nodeCount }) => {
  const { fitView } = useReactFlow();
  useEffect(() => {
    if (nodeCount === 0) return;
    const t = setTimeout(() => fitView({ padding: 0.25, duration: 400, maxZoom: 0.85 }), 150);
    return () => clearTimeout(t);
  }, [nodeCount, fitView]);
  return null;
};

const FlowInner: React.FC<PipelineFlowViewProps> = ({ agents, onNodeClick }) => {
  const nodes: Node[] = useMemo(() => {
    return agents.map((agent, index) => ({
      id: `agent-${agent.id}`,
      type: 'agentNode',
      position: { x: index * 280, y: 80 },
      data: {
        agentId: agent.id,
        name: agent.name,
        status: agent.status,
        duration: agent.duration,
        output: agent.output,
        onOpenDetails: () => onNodeClick(agent.id),
      },
    }));
  }, [agents, onNodeClick]);

  const edges: Edge[] = useMemo(() => {
    return agents.slice(0, -1).map((agent, index) => ({
      id: `edge-${agent.id}-${agents[index + 1].id}`,
      source: `agent-${agent.id}`,
      target: `agent-${agents[index + 1].id}`,
      type: ConnectionLineType.SmoothStep,
      animated: agents[index + 1].status === 'running',
      style: {
        stroke: agents[index + 1].status === 'running' ? '#2196f3' : '#555',
        strokeWidth: 2,
      },
      markerEnd: {
        type: MarkerType.ArrowClosed,
        color: agents[index + 1].status === 'running' ? '#2196f3' : '#555',
      },
    }));
  }, [agents]);

  return (
    <ReactFlow
      nodes={nodes}
      edges={edges}
      nodeTypes={nodeTypes}
      minZoom={0.2}
      maxZoom={2}
      attributionPosition="bottom-left"
      proOptions={{ hideAttribution: true }}
    >
      <FitViewOnMount nodeCount={nodes.length} />
      <Background color="#1a1f3a" gap={16} />
      <Controls />
      <MiniMap
        nodeColor={(node) => {
          const status = node.data.status;
          switch (status) {
            case 'success': return '#4caf50';
            case 'failed': return '#f44336';
            case 'running': return '#2196f3';
            case 'skipped': return '#ff9800';
            default: return '#757575';
          }
        }}
        style={{ background: '#1a1f3a' }}
      />
    </ReactFlow>
  );
};

const PipelineFlowView: React.FC<PipelineFlowViewProps> = ({ agents, onNodeClick }) => {
  return (
    <Box sx={{ width: '100%', height: '400px', background: '#0a0e27', borderRadius: 2 }}>
      <ReactFlowProvider>
        <FlowInner agents={agents} onNodeClick={onNodeClick} />
      </ReactFlowProvider>
    </Box>
  );
};

export default PipelineFlowView;
