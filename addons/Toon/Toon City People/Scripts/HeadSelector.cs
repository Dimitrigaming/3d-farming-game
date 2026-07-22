using System.Collections.Generic;
using UnityEngine;

namespace HeadSelector
{

    public class HeadSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_HEADS = 35
;
        [Range(0, MAXIMUM_NUMBER_HEADS - 1)]
        public int Head;
        public GameObject[] Heads = new GameObject[MAXIMUM_NUMBER_HEADS];


        void OnValidate()
        {
		ValidateObject(Head, Heads);

        }

        public void ValidateObject(int selectedIndex, GameObject[] objects)
        {
            if (selectedIndex > objects.Length)
                selectedIndex = objects.Length;

            for (int i = 0; i < objects.Length; i++)
            {
                if (objects[i] != null)
                    objects[i].SetActive(i == selectedIndex);
            }
        }
    }
}
