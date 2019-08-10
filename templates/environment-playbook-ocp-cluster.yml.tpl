---

- name: Manage ${ENVIRONMENT} OCP Cluster
  hosts: ${ENVIRONMENT}-ocp-cluster

  pre_tasks:
    - name: Get OCP cluster API KEY Token using username/password
      uri:
        url: "{{ ocp_cluster_host }}/oauth/authorize?client_id=openshift-challenging-client&response_type=token"
        validate_certs: no
        method: GET
        user: "{{ ocp_cluster_username }}"
        password: "{{ ocp_cluster_password }}"
        force_basic_auth: yes
        status_code: 200
        headers:
          X-CSRF-Token: "xxx"
      no_log: true
      check_mode: no
      register: access_token_register
      tags: always

    - name: Set OCP cluster API KEY Token
      set_fact:
        ocp_cluster_api_key_token: "{{ access_token_register.url | regex_search ('access_token=(.*)&expires', '\\1') | first }}"
      no_log: true
      check_mode: no
      tags: always

  roles:
   - { role: hello-world, tags: [ 'hello-world' ] }
