k8s configuration file only here! 



chmod +x k8s-setup.sh  
sudo NODE_ROLE=master ./k8s-setup.sh  
Prepare host for k8s






Yes — Kubernetes Ingress operates at Layer 7 (application layer, HTTP/HTTPS).
That's exactly why it can do things like:

Route by Host header (like your demo.local rule)
Route by path (/ vs /api splitting to different backends)
TLS termination
Header-based rules, rewrites, redirects, etc.

Compare that to:

L4 (Transport layer) load balancing — routes based purely on IP + port (TCP/UDP), with no visibility into HTTP content. A Kubernetes Service of type LoadBalancer (e.g. an AWS NLB) typically works at L4 — it just forwards packets to a pod IP:port, no knowledge of Host headers or paths.

So in your setup:

ingress-nginx-controller = the L7 layer — this is what inspects the Host: demo.local header and the / vs /api path, then decides which Service to send traffic to.
Underneath, that controller itself might be exposed via an L4 LoadBalancer/NodePort/Service to actually receive traffic from outside the cluster.

So the stack is often: L4 LB (gets traffic into the cluster) → L7 Ingress controller (nginx, smart routing by host/path) → Service (ClusterIP, routes to pod endpoints) → Pod.
That's the layer your Host and path rules in the demo Ingress are operating at — which is why fixing the Service selector was the missing piece; the L7 routing logic was already correct once the typo was fixed, it just had no healthy backend to hand traffic to.



















<img width="816" height="243" alt="Screenshot 2026-07-07 at 00 12 18" src="https://github.com/user-attachments/assets/3912e097-590a-4365-8764-12d968fb5d5d" />





<img width="818" height="587" alt="Screenshot 2026-07-07 at 00 12 59" src="https://github.com/user-attachments/assets/d06ffb26-b01d-4887-87e4-29999b63c75b" />





<img width="926" height="325" alt="Screenshot 2026-07-07 at 00 39 36" src="https://github.com/user-attachments/assets/bea35f58-0da9-4f76-9397-05712a9143ab" />






<img width="593" height="877" alt="Screenshot 2026-07-07 at 00 52 12" src="https://github.com/user-attachments/assets/9cc4977f-e791-4817-a083-0057b3e8f7ac" />







<img width="1464" height="634" alt="Screenshot 2026-07-07 at 01 48 06" src="https://github.com/user-attachments/assets/62e1b2a0-68ab-4a32-aee3-674ef0da7b50" />








<img width="1136" height="114" alt="Screenshot 2026-07-07 at 01 49 18" src="https://github.com/user-attachments/assets/8e3a4028-9013-4bcf-aec0-dd73067da9d1" />









Install ingress controller 
<img width="1456" height="606" alt="Screenshot 2026-07-07 at 01 46 54" src="https://github.com/user-attachments/assets/94d16db8-16e9-4094-9d3c-e58c80f417d7" />











<img width="1496" height="425" alt="Screenshot 2026-07-07 at 02 32 28" src="https://github.com/user-attachments/assets/b04e2f8b-0558-4e98-9571-a34d80e85f30" />
